#include "conversationmanager.h"
#include <QDateTime>
#include <QVector>
#include <QUuid>
#include <QJsonDocument>
#include <QDebug>
#include <QFile>
#include <QTextStream>
#include <QStandardPaths>
#include <QRegExp>

ConversationManager::ConversationManager(QObject *parent)
    : QObject(parent)
    , m_currentConversation(new ConversationModel(this))
    , m_settings("harbour-sailcat", "conversations")
    , m_totalPromptTokens(0)
    , m_totalCompletionTokens(0)
{
    m_totalPromptTokens = m_settings.value("stats/totalPromptTokens", 0).toLongLong();
    m_totalCompletionTokens = m_settings.value("stats/totalCompletionTokens", 0).toLongLong();

    loadAllConversations();

    // Si aucune conversation n'existe, en créer une nouvelle
    if (m_conversations.isEmpty()) {
        createNewConversation();
    } else {
        // Charger la dernière conversation utilisée
        QString lastId = m_settings.value("lastConversationId").toString();
        if (!lastId.isEmpty()) {
            loadConversation(lastId);
        } else {
            loadConversation(m_conversations.first().id);
        }
    }
}

void ConversationManager::createNewConversation()
{
    // Sauvegarder la conversation courante si elle existe
    if (!m_currentConversationId.isEmpty()) {
        saveCurrentConversation();
    }

    // Créer une nouvelle conversation
    Conversation newConv;
    newConv.id = generateConversationId();
    newConv.title = ""; // Sera généré automatiquement au premier message
    newConv.createdAt = QDateTime::currentMSecsSinceEpoch();
    newConv.updatedAt = newConv.createdAt;

    m_conversations.prepend(newConv);
    m_currentConversationId = newConv.id;

    // Vider le modèle actuel
    m_currentConversation->clearConversation();

    m_settings.setValue("lastConversationId", m_currentConversationId);

    emit currentConversationChanged();
    emit conversationCountChanged();
}

void ConversationManager::loadConversation(const QString &conversationId)
{
    // Sauvegarder la conversation courante
    if (!m_currentConversationId.isEmpty()) {
        saveCurrentConversation();
    }

    Conversation *conv = findConversation(conversationId);
    if (!conv) {
        qWarning() << "Conversation not found:" << conversationId;
        return;
    }

    m_currentConversationId = conversationId;
    m_currentConversation->clearConversation();

    // Load messages preserving their original timestamps
    for (const Message &msg : conv->messages) {
        m_currentConversation->addMessage(msg.role, msg.content, msg.timestamp, msg.pinned);
    }

    m_settings.setValue("lastConversationId", m_currentConversationId);

    emit currentConversationChanged();
}

void ConversationManager::deleteConversation(const QString &conversationId)
{
    for (int i = 0; i < m_conversations.count(); ++i) {
        if (m_conversations[i].id == conversationId) {
            m_conversations.removeAt(i);

            // Si c'est la conversation courante, en créer une nouvelle
            if (conversationId == m_currentConversationId) {
                createNewConversation();
            }

            saveAllConversations();
            emit conversationCountChanged();
            return;
        }
    }
}

void ConversationManager::renameConversation(const QString &conversationId, const QString &newTitle)
{
    Conversation *conv = findConversation(conversationId);
    if (conv) {
        conv->title = newTitle;
        conv->updatedAt = QDateTime::currentMSecsSinceEpoch();
        saveAllConversations();
    }
}

void ConversationManager::updateCurrentConversationTitle(const QString &newTitle)
{
    if (m_currentConversationId.isEmpty() || newTitle.isEmpty()) {
        return;
    }

    renameConversation(m_currentConversationId, newTitle);
}

QJsonArray ConversationManager::getConversationsList() const
{
    QJsonArray list;

    for (const Conversation &conv : m_conversations) {
        QJsonObject obj;
        obj["id"] = conv.id;
        obj["title"] = conv.title.isEmpty() ? tr("New conversation") : conv.title;
        obj["createdAt"] = conv.createdAt;
        obj["updatedAt"] = conv.updatedAt;
        obj["messageCount"] = conv.messages.count();
        obj["category"] = conv.category;

        int userCount = 0;
        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                userCount++;
            }
        }
        obj["userMessageCount"] = userCount;

        list.append(obj);
    }

    return list;
}

void ConversationManager::saveCurrentConversation()
{
    if (m_currentConversationId.isEmpty())
        return;

    Conversation *conv = findConversation(m_currentConversationId);
    if (!conv)
        return;

    // Collect messages from the model
    conv->messages.clear();
    QJsonArray messagesJson = m_currentConversation->toJsonArray();

    for (int i = 0; i < messagesJson.count(); ++i) {
        QJsonObject msgObj = messagesJson[i].toObject();
        Message msg;
        msg.role = msgObj["role"].toString();
        msg.content = msgObj["content"].toString();
        msg.timestamp = msgObj["timestamp"].toVariant().toLongLong();
        msg.pinned = msgObj["pinned"].toBool();
        conv->messages.append(msg);
    }

    // Générer un titre si nécessaire
    if (conv->title.isEmpty() && !conv->messages.isEmpty()) {
        conv->title = generateConversationTitle(conv->messages);
    }

    conv->updatedAt = QDateTime::currentMSecsSinceEpoch();

    saveAllConversations();
}

void ConversationManager::loadAllConversations()
{
    m_conversations.clear();

    QJsonDocument doc = QJsonDocument::fromJson(m_settings.value("conversations").toByteArray());
    if (!doc.isArray())
        return;

    QJsonArray array = doc.array();
    for (int i = 0; i < array.count(); ++i) {
        QJsonObject obj = array[i].toObject();

        Conversation conv;
        conv.id = obj["id"].toString();
        conv.title = obj["title"].toString();
        conv.category = obj["category"].toString();
        conv.createdAt = obj["createdAt"].toVariant().toLongLong();
        conv.updatedAt = obj["updatedAt"].toVariant().toLongLong();
        conv.totalTokens = obj["totalTokens"].toVariant().toLongLong();

        QJsonArray messagesArray = obj["messages"].toArray();
        for (int j = 0; j < messagesArray.count(); ++j) {
            QJsonObject msgObj = messagesArray[j].toObject();
            Message msg;
            msg.role = msgObj["role"].toString();
            msg.content = msgObj["content"].toString();
            msg.timestamp = msgObj["timestamp"].toVariant().toLongLong();
            msg.pinned = msgObj["pinned"].toBool();
            conv.messages.append(msg);
        }

        m_conversations.append(conv);
    }
}

void ConversationManager::saveAllConversations()
{
    QJsonArray array;

    for (const Conversation &conv : m_conversations) {
        QJsonObject obj;
        obj["id"] = conv.id;
        obj["title"] = conv.title;
        obj["category"] = conv.category;
        obj["createdAt"] = conv.createdAt;
        obj["updatedAt"] = conv.updatedAt;
        obj["totalTokens"] = conv.totalTokens;

        QJsonArray messagesArray;
        for (const Message &msg : conv.messages) {
            QJsonObject msgObj;
            msgObj["role"] = msg.role;
            msgObj["content"] = msg.content;
            msgObj["timestamp"] = msg.timestamp;
            msgObj["pinned"] = msg.pinned;
            messagesArray.append(msgObj);
        }
        obj["messages"] = messagesArray;

        array.append(obj);
    }

    QJsonDocument doc(array);
    m_settings.setValue("conversations", doc.toJson(QJsonDocument::Compact));
}

QString ConversationManager::generateConversationId() const
{
    // Qt 5.6 doesn't have QUuid::WithoutBraces, so we manually remove braces
    QString uuid = QUuid::createUuid().toString();
    return uuid.mid(1, uuid.length() - 2);  // Remove { and }
}

QString ConversationManager::generateConversationTitle(const QList<Message> &messages) const
{
    // Prendre le premier message utilisateur et le tronquer
    for (const Message &msg : messages) {
        if (msg.role == "user") {
            QString title = msg.content.trimmed();
            if (title.length() > 50) {
                title = title.left(47) + "...";
            }
            return title;
        }
    }
    return tr("New conversation");
}

Conversation* ConversationManager::findConversation(const QString &id)
{
    for (int i = 0; i < m_conversations.count(); ++i) {
        if (m_conversations[i].id == id) {
            return &m_conversations[i];
        }
    }
    return nullptr;
}

QVariant ConversationManager::getConversationDetails(const QString &conversationId) const
{
    QVariantMap details;

    for (const Conversation &conv : m_conversations) {
        if (conv.id == conversationId) {
            details["id"] = conv.id;
            details["title"] = conv.title;
            details["createdAt"] = conv.createdAt;
            details["updatedAt"] = conv.updatedAt;

            QVariantList messagesList;
            for (const Message &msg : conv.messages) {
                QVariantMap msgMap;
                msgMap["role"] = msg.role;
                msgMap["content"] = msg.content;
                msgMap["timestamp"] = msg.timestamp;
                messagesList.append(msgMap);
            }
            details["messages"] = messagesList;
            details["messageCount"] = conv.messages.count();

            break;
        }
    }

    return details;
}

qint64 ConversationManager::getStorageSize() const
{
    QByteArray data = m_settings.value("conversations").toByteArray();
    return data.size();
}

QString ConversationManager::getStorageSizeFormatted() const
{
    qint64 bytes = getStorageSize();

    if (bytes < 1024) {
        return QString("%1 B").arg(bytes);
    } else if (bytes < 1024 * 1024) {
        return QString("%1 KB").arg(bytes / 1024.0, 0, 'f', 2);
    } else {
        return QString("%1 MB").arg(bytes / (1024.0 * 1024.0), 0, 'f', 2);
    }
}

void ConversationManager::purgeAllConversations()
{
    m_conversations.clear();
    m_settings.remove("conversations");
    m_settings.remove("lastConversationId");

    // Create a new empty conversation
    createNewConversation();

    emit conversationCountChanged();
}

void ConversationManager::updateCurrentConversationCategory(const QString &category)
{
    if (m_currentConversationId.isEmpty() || category.isEmpty()) {
        return;
    }

    Conversation *conv = findConversation(m_currentConversationId);
    if (conv) {
        conv->category = category;
        saveAllConversations();
    }
}

QString ConversationManager::currentConversationId() const
{
    return m_currentConversationId;
}

QVariantList ConversationManager::getPinnedMessages() const
{
    QVariantList result;

    for (const Conversation &conv : m_conversations) {
        for (int i = 0; i < conv.messages.count(); ++i) {
            const Message &msg = conv.messages.at(i);
            if (!msg.pinned) {
                continue;
            }
            QVariantMap entry;
            entry["conversationId"] = conv.id;
            entry["conversationTitle"] = conv.title.isEmpty() ? tr("Untitled") : conv.title;
            entry["messageIndex"] = i;
            entry["role"] = msg.role;
            entry["content"] = msg.content;
            entry["timestamp"] = msg.timestamp;
            result.append(entry);
        }
    }

    return result;
}

QString ConversationManager::conversationToMarkdown(const QString &conversationId) const
{
    for (const Conversation &conv : m_conversations) {
        if (conv.id != conversationId) {
            continue;
        }

        QString markdown;
        markdown += "# " + (conv.title.isEmpty() ? tr("Untitled") : conv.title) + "\n\n";
        markdown += QString("_Exported from SailCat - %1_\n\n")
                .arg(QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm"));

        for (const Message &msg : conv.messages) {
            markdown += (msg.role == "user") ? "## User\n\n" : "## Assistant\n\n";
            markdown += msg.content + "\n\n";
        }
        return markdown;
    }
    return QString();
}

QString ConversationManager::exportConversation(const QString &conversationId) const
{
    QString markdown = conversationToMarkdown(conversationId);
    if (markdown.isEmpty()) {
        return QString();
    }

    QString title;
    for (const Conversation &conv : m_conversations) {
        if (conv.id == conversationId) {
            title = conv.title;
            break;
        }
    }

    // Filesystem-safe slug from the title
    QString slug = title.toLower();
    slug.replace(QRegExp("[^a-z0-9]+"), "-");
    slug.replace(QRegExp("(^-+|-+$)"), "");
    if (slug.length() > 40) {
        slug = slug.left(40);
    }
    if (slug.isEmpty()) {
        slug = "conversation";
    }

    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QString path = QString("%1/sailcat-%2-%3.md")
            .arg(dir)
            .arg(slug)
            .arg(QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss"));

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Export failed:" << file.errorString();
        return QString();
    }

    QTextStream stream(&file);
    // Qt 5.6 defaults to the locale codec; force UTF-8
    stream.setCodec("UTF-8");
    stream << markdown;
    file.close();

    return path;
}

void ConversationManager::addTokenUsage(int promptTokens, int completionTokens)
{
    if (promptTokens <= 0 && completionTokens <= 0) {
        return;
    }
    int total = promptTokens + completionTokens;

    m_totalPromptTokens += promptTokens;
    m_totalCompletionTokens += completionTokens;
    // Persist immediately so counters survive a crash
    m_settings.setValue("stats/totalPromptTokens", m_totalPromptTokens);
    m_settings.setValue("stats/totalCompletionTokens", m_totalCompletionTokens);

    // Daily series for the usage charts, pruned to ~2 months
    QJsonObject daily = QJsonDocument::fromJson(
                m_settings.value("stats/dailyTokens").toByteArray()).object();
    QString today = QDate::currentDate().toString("yyyy-MM-dd");
    daily[today] = daily[today].toInt() + total;

    QDate pruneLimit = QDate::currentDate().addDays(-62);
    for (const QString &key : daily.keys()) {
        if (QDate::fromString(key, "yyyy-MM-dd") < pruneLimit) {
            daily.remove(key);
        }
    }
    m_settings.setValue("stats/dailyTokens",
                        QJsonDocument(daily).toJson(QJsonDocument::Compact));
    m_settings.sync();

    // Per-conversation counter
    Conversation *conv = findConversation(m_currentConversationId);
    if (conv) {
        conv->totalTokens += total;
        saveAllConversations();
    }
}

QVariantMap ConversationManager::getConversationStatistics(const QString &conversationId) const
{
    QVariantMap stats;

    for (const Conversation &conv : m_conversations) {
        if (conv.id != conversationId) {
            continue;
        }

        int userCount = 0;
        int assistantCount = 0;
        qint64 totalChars = 0;
        qint64 userChars = 0;
        qint64 assistantChars = 0;
        int longestChars = 0;
        QVariantList rhythm;

        // Cap the rhythm chart to the last 40 messages
        int rhythmStart = qMax(0, conv.messages.count() - 40);

        for (int i = 0; i < conv.messages.count(); ++i) {
            const Message &msg = conv.messages.at(i);
            if (msg.role == "user") {
                userCount++;
                userChars += msg.content.length();
            } else {
                assistantCount++;
                assistantChars += msg.content.length();
            }
            totalChars += msg.content.length();
            longestChars = qMax(longestChars, msg.content.length());

            if (i >= rhythmStart) {
                QVariantMap bar;
                bar["chars"] = msg.content.length();
                bar["role"] = msg.role;
                rhythm.append(bar);
            }
        }

        int count = conv.messages.count();
        stats["messageCount"] = count;
        stats["userCount"] = userCount;
        stats["assistantCount"] = assistantCount;
        stats["totalChars"] = totalChars;
        stats["userChars"] = userChars;
        stats["assistantChars"] = assistantChars;
        stats["avgChars"] = count > 0 ? int(totalChars / count) : 0;
        stats["longestChars"] = longestChars;
        stats["estimatedTokens"] = totalChars / 4;
        stats["category"] = conv.category;
        stats["totalTokens"] = conv.totalTokens;

        qint64 durationMs = 0;
        if (count > 1) {
            durationMs = conv.messages.last().timestamp - conv.messages.first().timestamp;
        }
        stats["durationMs"] = durationMs;
        stats["rhythm"] = rhythm;
        break;
    }

    return stats;
}

QVariantMap ConversationManager::getStatistics() const
{
    QVariantMap stats;

    int totalMessages = 0;
    int totalUserMessages = 0;
    int totalAssistantMessages = 0;
    int longestConvMessages = 0;
    int longestMessageLength = 0;
    qint64 estimatedTokens = 0;
    qint64 firstMessageDate = 0;
    qint64 totalUserChars = 0;
    qint64 totalAssistantChars = 0;
    QString longestConvTitle;
    QVariantMap categoryCounts;

    // Activity distribution: last 14 days (oldest first) and hour of day
    QDate today = QDate::currentDate();
    QVector<int> dayCounts(14, 0);
    QVector<int> hourCounts(24, 0);

    for (const Conversation &conv : m_conversations) {
        int convMessageCount = conv.messages.count();
        totalMessages += convMessageCount;

        if (convMessageCount > 0) {
            QString cat = conv.category.isEmpty() ? "other" : conv.category;
            categoryCounts[cat] = categoryCounts[cat].toInt() + 1;
        }

        if (convMessageCount > longestConvMessages) {
            longestConvMessages = convMessageCount;
            longestConvTitle = conv.title.isEmpty() ? tr("Untitled") : conv.title;
        }

        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                totalUserMessages++;
                totalUserChars += msg.content.length();
            } else if (msg.role == "assistant") {
                totalAssistantMessages++;
                totalAssistantChars += msg.content.length();
            }

            // Find longest message
            if (msg.content.length() > longestMessageLength) {
                longestMessageLength = msg.content.length();
            }

            // Estimate tokens (rough approximation: ~4 chars per token)
            estimatedTokens += msg.content.length() / 4;

            // Track first message date
            if (firstMessageDate == 0 || msg.timestamp < firstMessageDate) {
                firstMessageDate = msg.timestamp;
            }

            // Activity distribution
            if (msg.timestamp > 0) {
                QDateTime dt = QDateTime::fromMSecsSinceEpoch(msg.timestamp);
                int daysAgo = dt.date().daysTo(today);
                if (daysAgo >= 0 && daysAgo < 14) {
                    dayCounts[13 - daysAgo]++;
                }
                hourCounts[dt.time().hour()]++;
            }
        }
    }

    QVariantList messagesPerDay;
    for (int i = 0; i < 14; ++i) {
        messagesPerDay.append(dayCounts.at(i));
    }

    QVariantList messagesPerHour;
    for (int i = 0; i < 24; ++i) {
        messagesPerHour.append(hourCounts.at(i));
    }

    stats["totalMessages"] = totalMessages;
    stats["totalUserMessages"] = totalUserMessages;
    stats["totalAssistantMessages"] = totalAssistantMessages;
    stats["totalConversations"] = m_conversations.count();
    stats["longestConvMessages"] = longestConvMessages;
    stats["longestConvTitle"] = longestConvTitle;
    stats["longestMessageLength"] = longestMessageLength;
    stats["estimatedTokens"] = estimatedTokens;
    stats["totalPromptTokens"] = m_totalPromptTokens;
    stats["totalCompletionTokens"] = m_totalCompletionTokens;
    stats["totalTokens"] = m_totalPromptTokens + m_totalCompletionTokens;
    stats["totalUserChars"] = totalUserChars;
    stats["totalAssistantChars"] = totalAssistantChars;
    stats["categoryCounts"] = categoryCounts;

    // Token usage over time
    QJsonObject daily = QJsonDocument::fromJson(
                m_settings.value("stats/dailyTokens").toByteArray()).object();
    QVariantList tokensPerDay;
    qint64 tokensThisMonth = 0;
    for (int i = 13; i >= 0; --i) {
        QDate d = today.addDays(-i);
        tokensPerDay.append(daily[d.toString("yyyy-MM-dd")].toInt());
    }
    for (const QString &key : daily.keys()) {
        QDate d = QDate::fromString(key, "yyyy-MM-dd");
        if (d.year() == today.year() && d.month() == today.month()) {
            tokensThisMonth += daily[key].toInt();
        }
    }
    stats["tokensPerDay"] = tokensPerDay;
    stats["tokensThisMonth"] = tokensThisMonth;
    stats["firstMessageDate"] = firstMessageDate;
    stats["messagesPerDay"] = messagesPerDay;
    stats["messagesPerHour"] = messagesPerHour;

    return stats;
}

QVariantList ConversationManager::searchConversations(const QString &query) const
{
    QVariantList results;

    if (query.trimmed().isEmpty()) {
        return results;
    }

    QString searchQuery = query.trimmed().toLower();

    for (const Conversation &conv : m_conversations) {
        bool titleMatch = conv.title.toLower().contains(searchQuery);
        int matchCount = 0;
        QString matchPreview;

        // Search in messages
        int userCount = 0;
        for (const Message &msg : conv.messages) {
            if (msg.role == "user") {
                userCount++;
            }
            if (msg.content.toLower().contains(searchQuery)) {
                matchCount++;

                // Get preview of first match if we don't have one yet
                if (matchPreview.isEmpty()) {
                    int pos = msg.content.toLower().indexOf(searchQuery);
                    int start = qMax(0, pos - 40);
                    int length = qMin(100, msg.content.length() - start);
                    matchPreview = msg.content.mid(start, length);

                    if (start > 0) {
                        matchPreview = "..." + matchPreview;
                    }
                    if (start + length < msg.content.length()) {
                        matchPreview = matchPreview + "...";
                    }
                }
            }
        }

        // If we have matches or title match, add to results
        if (titleMatch || matchCount > 0) {
            QVariantMap result;
            result["id"] = conv.id;
            result["title"] = conv.title.isEmpty() ? tr("Untitled") : conv.title;
            result["createdAt"] = conv.createdAt;
            result["updatedAt"] = conv.updatedAt;
            result["messageCount"] = conv.messages.count();
            result["userMessageCount"] = userCount;
            result["category"] = conv.category;
            result["matchCount"] = matchCount;
            result["matchPreview"] = matchPreview.isEmpty() ? tr("Match in title") : matchPreview;
            result["titleMatch"] = titleMatch;

            results.append(result);
        }
    }

    return results;
}
