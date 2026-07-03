#ifndef SETTINGSMANAGER_H
#define SETTINGSMANAGER_H

#include <QObject>
#include <QSettings>
#include <QString>
#include <QStringList>
#include <QVariant>

class SettingsManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(QString modelName READ modelName WRITE setModelName NOTIFY modelNameChanged)
    Q_PROPERTY(QString nextMessageModel READ nextMessageModel WRITE setNextMessageModel NOTIFY nextMessageModelChanged)
    Q_PROPERTY(bool useCustomKey READ useCustomKey WRITE setUseCustomKey NOTIFY useCustomKeyChanged)
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(bool hasApiKey READ hasApiKey NOTIFY hasApiKeyChanged)
    Q_PROPERTY(double temperature READ temperature WRITE setTemperature NOTIFY temperatureChanged)
    Q_PROPERTY(int maxTokens READ maxTokens WRITE setMaxTokens NOTIFY maxTokensChanged)
    Q_PROPERTY(QString systemPrompt READ systemPrompt WRITE setSystemPrompt NOTIFY systemPromptChanged)

public:
    explicit SettingsManager(QObject *parent = nullptr);

    QString apiKey() const;
    void setApiKey(const QString &key);

    QString modelName() const;
    void setModelName(const QString &model);

    QString nextMessageModel() const;
    void setNextMessageModel(const QString &model);

    bool useCustomKey() const;
    void setUseCustomKey(bool use);

    QString language() const;
    void setLanguage(const QString &lang);

    double temperature() const;
    void setTemperature(double temperature);

    int maxTokens() const;
    void setMaxTokens(int maxTokens);

    QString systemPrompt() const;
    void setSystemPrompt(const QString &prompt);

    bool hasApiKey() const;

    Q_INVOKABLE QStringList availableModels() const;
    Q_INVOKABLE QStringList availableLanguages() const;
    Q_INVOKABLE bool isVisionModel(const QString &modelId) const;
    Q_INVOKABLE void updateModelCache(const QVariantList &models);
    Q_INVOKABLE bool modelCacheStale() const;
    Q_INVOKABLE void clearApiKey();
    Q_INVOKABLE bool isFirstLaunch() const;
    Q_INVOKABLE void setFirstLaunchComplete();
    Q_INVOKABLE void resetNextMessageModel();

signals:
    void apiKeyChanged();
    void modelNameChanged();
    void nextMessageModelChanged();
    void useCustomKeyChanged();
    void languageChanged();
    void hasApiKeyChanged();
    void temperatureChanged();
    void maxTokensChanged();
    void systemPromptChanged();
    void availableModelsChanged();

private:
    QSettings m_settings;
    QString m_apiKey;
    QString m_modelName;
    QString m_nextMessageModel;
    bool m_useCustomKey;
    QString m_language;
    double m_temperature;
    int m_maxTokens;
    QString m_systemPrompt;
    QStringList m_cachedModels;
    QStringList m_cachedVisionModels;

    void loadSettings();
    void saveSettings();
};

#endif // SETTINGSMANAGER_H
