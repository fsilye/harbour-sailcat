#include "settingsmanager.h"
#include <QDateTime>

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
    , m_settings("harbour-sailcat", "SailCat")
    , m_useCustomKey(false)
    , m_temperature(-1.0)
    , m_maxTokens(0)
{
    loadSettings();
}

QString SettingsManager::apiKey() const
{
    return m_apiKey;
}

void SettingsManager::setApiKey(const QString &key)
{
    if (m_apiKey != key) {
        bool hadKey = !m_apiKey.isEmpty();
        m_apiKey = key;
        bool hasKey = !m_apiKey.isEmpty();
        saveSettings();
        emit apiKeyChanged();
        if (hadKey != hasKey) {
            emit hasApiKeyChanged();
        }
    }
}

QString SettingsManager::modelName() const
{
    return m_modelName;
}

void SettingsManager::setModelName(const QString &model)
{
    if (m_modelName != model) {
        m_modelName = model;
        saveSettings();
        emit modelNameChanged();
    }
}

bool SettingsManager::useCustomKey() const
{
    return m_useCustomKey;
}

void SettingsManager::setUseCustomKey(bool use)
{
    if (m_useCustomKey != use) {
        m_useCustomKey = use;
        saveSettings();
        emit useCustomKeyChanged();
    }
}

QString SettingsManager::language() const
{
    return m_language;
}

void SettingsManager::setLanguage(const QString &lang)
{
    if (m_language != lang) {
        m_language = lang;
        saveSettings();
        emit languageChanged();
    }
}

double SettingsManager::temperature() const
{
    return m_temperature;
}

void SettingsManager::setTemperature(double temperature)
{
    if (m_temperature != temperature) {
        m_temperature = temperature;
        saveSettings();
        emit temperatureChanged();
    }
}

int SettingsManager::maxTokens() const
{
    return m_maxTokens;
}

void SettingsManager::setMaxTokens(int maxTokens)
{
    if (m_maxTokens != maxTokens) {
        m_maxTokens = maxTokens;
        saveSettings();
        emit maxTokensChanged();
    }
}

QString SettingsManager::systemPrompt() const
{
    return m_systemPrompt;
}

void SettingsManager::setSystemPrompt(const QString &prompt)
{
    if (m_systemPrompt != prompt) {
        m_systemPrompt = prompt;
        saveSettings();
        emit systemPromptChanged();
    }
}

QStringList SettingsManager::availableModels() const
{
    if (!m_cachedModels.isEmpty()) {
        return m_cachedModels;
    }
    // Fallback when the model list was never fetched
    return QStringList()
        << "mistral-small-latest"
        << "mistral-large-latest"
        << "pixtral-12b-latest";
}

bool SettingsManager::isVisionModel(const QString &modelId) const
{
    if (!m_cachedModels.isEmpty()) {
        return m_cachedVisionModels.contains(modelId);
    }
    return modelId.contains("pixtral");
}

void SettingsManager::updateModelCache(const QVariantList &models)
{
    QStringList ids;
    QStringList visionIds;

    for (const QVariant &modelVariant : models) {
        QVariantMap model = modelVariant.toMap();
        QString id = model["id"].toString();
        if (id.isEmpty()) {
            continue;
        }
        ids.append(id);
        if (model["vision"].toBool()) {
            visionIds.append(id);
        }
    }

    if (ids.isEmpty()) {
        return;
    }

    m_cachedModels = ids;
    m_cachedVisionModels = visionIds;
    m_settings.setValue("models/cachedList", m_cachedModels);
    m_settings.setValue("models/visionList", m_cachedVisionModels);
    m_settings.setValue("models/cacheTimestamp", QDateTime::currentMSecsSinceEpoch() / 1000);
    m_settings.sync();
    emit availableModelsChanged();
}

bool SettingsManager::modelCacheStale() const
{
    if (m_cachedModels.isEmpty()) {
        return true;
    }
    qint64 cachedAt = m_settings.value("models/cacheTimestamp", 0).toLongLong();
    qint64 now = QDateTime::currentMSecsSinceEpoch() / 1000;
    return (now - cachedAt) > 24 * 3600;
}

QStringList SettingsManager::availableLanguages() const
{
    return QStringList()
        << "en"
        << "fr"
        << "de"
        << "es"
        << "fi"
        << "it";
}

void SettingsManager::clearApiKey()
{
    setApiKey(QString());
}

bool SettingsManager::hasApiKey() const
{
    return !m_apiKey.isEmpty();
}

QString SettingsManager::nextMessageModel() const
{
    return m_nextMessageModel;
}

void SettingsManager::setNextMessageModel(const QString &model)
{
    if (m_nextMessageModel != model) {
        m_nextMessageModel = model;
        saveSettings();
        emit nextMessageModelChanged();
    }
}

void SettingsManager::resetNextMessageModel()
{
    setNextMessageModel(QString());
}

bool SettingsManager::isFirstLaunch() const
{
    // If the flag is set and true, never show again
    if (m_settings.value("firstLaunchComplete", false).toBool()) {
        return false;
    }

    // Show if no API key configured
    return m_apiKey.isEmpty();
}

void SettingsManager::setFirstLaunchComplete()
{
    m_settings.setValue("firstLaunchComplete", true);
    m_settings.sync();
}

void SettingsManager::loadSettings()
{
    m_apiKey = m_settings.value("apiKey", "").toString();
    m_modelName = m_settings.value("modelName", "mistral-small-latest").toString();
    m_nextMessageModel = m_settings.value("nextMessageModel", "").toString();
    m_useCustomKey = m_settings.value("useCustomKey", false).toBool();
    m_language = m_settings.value("language", "en").toString();
    m_temperature = m_settings.value("generation/temperature", -1.0).toDouble();
    m_maxTokens = m_settings.value("generation/maxTokens", 0).toInt();
    m_systemPrompt = m_settings.value("generation/systemPrompt", "").toString();
    m_cachedModels = m_settings.value("models/cachedList").toStringList();
    m_cachedVisionModels = m_settings.value("models/visionList").toStringList();
}

void SettingsManager::saveSettings()
{
    m_settings.setValue("apiKey", m_apiKey);
    m_settings.setValue("modelName", m_modelName);
    if (!m_nextMessageModel.isEmpty()) {
        m_settings.setValue("nextMessageModel", m_nextMessageModel);
    } else {
        m_settings.remove("nextMessageModel");
    }
    m_settings.setValue("useCustomKey", m_useCustomKey);
    m_settings.setValue("language", m_language);
    m_settings.setValue("generation/temperature", m_temperature);
    m_settings.setValue("generation/maxTokens", m_maxTokens);
    m_settings.setValue("generation/systemPrompt", m_systemPrompt);
    m_settings.sync();
}
