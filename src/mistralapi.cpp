#include "mistralapi.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QDebug>

static const int REQUEST_TIMEOUT_MS = 60000;

MistralAPI::MistralAPI(QObject *parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_timeoutTimer(new QTimer(this))
    , m_isBusy(false)
    , m_timedOut(false)
{
    m_timeoutTimer->setSingleShot(true);
    m_timeoutTimer->setInterval(REQUEST_TIMEOUT_MS);
    connect(m_timeoutTimer, &QTimer::timeout, this, &MistralAPI::onTimeout);
}

bool MistralAPI::isBusy() const
{
    return m_isBusy;
}

QString MistralAPI::error() const
{
    return m_error;
}

void MistralAPI::sendMessage(const QString &apiKey,
                               const QString &modelName,
                               const QVariant &messagesVariant)
{
    if (m_isBusy) {
        qWarning() << "Request already in progress";
        return;
    }

    if (apiKey.isEmpty()) {
        setError(tr("Missing API key. Please configure your API key in settings."));
        return;
    }

    // Convert QVariant (QVariantList) to QJsonArray
    QVariantList messagesList = messagesVariant.toList();
    if (messagesList.isEmpty()) {
        qWarning() << "Messages list is empty or invalid";
        setError(tr("Failed to prepare messages for API"));
        return;
    }

    QJsonArray messages;
    for (const QVariant &msgVariant : messagesList) {
        QVariantMap msgMap = msgVariant.toMap();
        QJsonObject msgObj;
        msgObj["role"] = msgMap["role"].toString();
        msgObj["content"] = msgMap["content"].toString();
        messages.append(msgObj);
    }

    setIsBusy(true);
    setError(QString());
    m_streamBuffer.clear();
    m_timedOut = false;

    // Build JSON request
    QJsonObject requestBody;
    requestBody["model"] = modelName;
    requestBody["messages"] = messages;
    requestBody["stream"] = true;

    QJsonDocument doc(requestBody);
    QByteArray jsonData = doc.toJson();

    // Configure HTTP request
    QNetworkRequest request(QUrl("https://api.mistral.ai/v1/chat/completions"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());
    request.setRawHeader("Accept", "text/event-stream");

    // Send request
    m_currentReply = m_networkManager->post(request, jsonData);

    connect(m_currentReply, &QNetworkReply::readyRead,
            this, &MistralAPI::onReadyRead);
    connect(m_currentReply, &QNetworkReply::finished,
            this, &MistralAPI::onFinished);
    connect(m_currentReply, SIGNAL(error(QNetworkReply::NetworkError)),
            this, SLOT(onError(QNetworkReply::NetworkError)));

    m_timeoutTimer->start();

    emit messageSent();
}

void MistralAPI::generateTitle(const QString &apiKey,
                                 const QString &modelName,
                                 const QString &firstUserMessage)
{
    if (apiKey.isEmpty() || firstUserMessage.isEmpty()) {
        return;
    }

    // Build request for title generation (non-streaming)
    QJsonArray messages;
    QJsonObject systemMsg;
    systemMsg["role"] = "system";
    systemMsg["content"] = "Generate a short conversation title (max 50 characters) based on the user's first message. Reply with ONLY the title, no explanation.";
    messages.append(systemMsg);

    QJsonObject userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = firstUserMessage;
    messages.append(userMsg);

    QJsonObject requestBody;
    requestBody["model"] = modelName;
    requestBody["messages"] = messages;
    requestBody["stream"] = false;  // Non-streaming for title generation

    QJsonDocument doc(requestBody);
    QByteArray jsonData = doc.toJson();

    // Configure HTTP request
    QNetworkRequest request(QUrl("https://api.mistral.ai/v1/chat/completions"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());

    // Send request
    QNetworkReply *reply = m_networkManager->post(request, jsonData);

    connect(reply, &QNetworkReply::finished,
            this, &MistralAPI::onTitleGenerationFinished);
}

void MistralAPI::cancelRequest()
{
    if (m_currentReply) {
        m_currentReply->abort();
    }
}

void MistralAPI::clearError()
{
    setError(QString());
}

void MistralAPI::onReadyRead()
{
    if (!m_currentReply)
        return;

    // Restart timeout on activity so long streams are not aborted
    m_timeoutTimer->start();
    processStreamData(m_currentReply->readAll());
}

void MistralAPI::onFinished()
{
    if (!m_currentReply)
        return;

    m_timeoutTimer->stop();

    // Process remaining data
    if (m_currentReply->error() == QNetworkReply::NoError) {
        QByteArray remaining = m_currentReply->readAll();
        if (!remaining.isEmpty()) {
            processStreamData(remaining);
        }
    }

    m_currentReply->deleteLater();
    m_currentReply = nullptr;
    setIsBusy(false);

    emit responseCompleted();
}

void MistralAPI::onError(QNetworkReply::NetworkError error)
{
    if (!m_currentReply)
        return;

    // User cancellation is not an error; timeout gets its own message
    if (error == QNetworkReply::OperationCanceledError) {
        if (m_timedOut) {
            setError(tr("Request timed out. Please check your connection."));
        }
        return;
    }

    QString errorString = m_currentReply->errorString();
    QByteArray responseData = m_currentReply->readAll();

    // Try to extract a more detailed error message from the JSON body
    if (!responseData.isEmpty()) {
        QJsonDocument doc = QJsonDocument::fromJson(responseData);
        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            if (obj.contains("error")) {
                QJsonValue errorValue = obj["error"];
                if (errorValue.isObject()) {
                    QString message = errorValue.toObject()["message"].toString();
                    if (!message.isEmpty()) {
                        errorString = message;
                    }
                } else if (errorValue.isString()) {
                    errorString = errorValue.toString();
                }
            }
        }
    }

    setError(tr("API Error: %1").arg(errorString));
    qWarning() << "API Error:" << errorString;
}

void MistralAPI::setIsBusy(bool busy)
{
    if (m_isBusy != busy) {
        m_isBusy = busy;
        emit isBusyChanged();
    }
}

void MistralAPI::setError(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
}

void MistralAPI::processStreamData(const QByteArray &data)
{
    // Buffer raw bytes: a multi-byte UTF-8 character can be split across
    // network chunks, so decode only complete lines
    m_streamBuffer.append(data);

    int newlinePos;
    while ((newlinePos = m_streamBuffer.indexOf('\n')) != -1) {
        QString line = QString::fromUtf8(m_streamBuffer.left(newlinePos)).trimmed();
        m_streamBuffer.remove(0, newlinePos + 1);

        if (!line.isEmpty()) {
            parseStreamLine(line);
        }
    }
}

void MistralAPI::onTimeout()
{
    if (m_currentReply) {
        m_timedOut = true;
        m_currentReply->abort();
    }
}

void MistralAPI::onTitleGenerationFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply)
        return;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray responseData = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(responseData);

        if (doc.isObject()) {
            QJsonObject obj = doc.object();
            QJsonArray choices = obj["choices"].toArray();

            if (!choices.isEmpty()) {
                QJsonObject choice = choices.at(0).toObject();
                QJsonObject message = choice["message"].toObject();
                QString title = message["content"].toString().trimmed();

                // Remove quotes if present
                if (title.startsWith("\"") && title.endsWith("\"")) {
                    title = title.mid(1, title.length() - 2);
                }

                // Truncate if too long
                if (title.length() > 50) {
                    title = title.left(47) + "...";
                }

                emit titleGenerated(title);
            }
        }
    } else {
        qWarning() << "Title generation failed:" << reply->errorString();
    }

    reply->deleteLater();
}

void MistralAPI::parseStreamLine(const QString &line)
{
    // SSE (Server-Sent Events) format uses "data: " as prefix
    if (!line.startsWith("data: ")) {
        return;
    }

    QString jsonData = line.mid(6); // Remove "data: "

    // Check for end-of-stream marker
    if (jsonData == "[DONE]") {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(jsonData.toUtf8());
    if (!doc.isObject()) {
        return;
    }

    QJsonObject obj = doc.object();

    // Extract delta content
    QJsonArray choices = obj["choices"].toArray();
    if (!choices.isEmpty()) {
        QJsonObject choice = choices.at(0).toObject();
        QJsonObject delta = choice["delta"].toObject();

        if (delta.contains("content")) {
            QString content = delta["content"].toString();
            if (!content.isEmpty()) {
                emit streamingResponse(content);
            }
        }
    }
}
