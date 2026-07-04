#include <QtTest>
#include <QCoreApplication>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QJsonArray>
#include <QJsonObject>

#include "conversationmodel.h"
#include "conversationmanager.h"
#include "mistralapi.h"

class TestConversationModel : public QObject
{
    Q_OBJECT

private slots:
    void addMessages()
    {
        ConversationModel model;
        QCOMPARE(model.rowCount(), 0);

        model.addUserMessage("hello");
        model.addAssistantMessage("hi there");
        QCOMPARE(model.rowCount(), 2);

        QJsonArray json = model.toJsonArray();
        QCOMPARE(json.at(0).toObject()["role"].toString(), QString("user"));
        QCOMPARE(json.at(0).toObject()["content"].toString(), QString("hello"));
        QCOMPARE(json.at(0).toObject()["pinned"].toBool(), false);
        QCOMPARE(json.at(1).toObject()["role"].toString(), QString("assistant"));
    }

    void updateLastAssistant()
    {
        ConversationModel model;
        model.addUserMessage("question");
        // No assistant message yet: update creates one
        model.updateLastAssistantMessage("partial");
        QCOMPARE(model.rowCount(), 2);
        model.updateLastAssistantMessage("partial answer");
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.getLastAssistantMessage(), QString("partial answer"));
    }

    void removeLastMessageIfEmpty()
    {
        ConversationModel model;
        model.addUserMessage("question");
        model.addAssistantMessage("");
        QCOMPARE(model.rowCount(), 2);
        model.removeLastMessageIfEmpty();
        QCOMPARE(model.rowCount(), 1);
        // Non-empty assistant message is kept
        model.addAssistantMessage("answer");
        model.removeLastMessageIfEmpty();
        QCOMPARE(model.rowCount(), 2);
    }

    void removeLastAssistantMessage()
    {
        ConversationModel model;
        model.addUserMessage("question");
        model.addAssistantMessage("answer");
        model.removeLastAssistantMessage();
        QCOMPARE(model.rowCount(), 1);
        // No-op when the last message is from the user
        model.removeLastAssistantMessage();
        QCOMPARE(model.rowCount(), 1);
    }

    void truncateFrom()
    {
        ConversationModel model;
        model.addUserMessage("one");
        model.addAssistantMessage("two");
        model.addUserMessage("three");
        model.addAssistantMessage("four");

        model.truncateFrom(10);  // out of range: no-op
        QCOMPARE(model.rowCount(), 4);
        model.truncateFrom(-1);
        QCOMPARE(model.rowCount(), 4);

        model.truncateFrom(2);
        QCOMPARE(model.rowCount(), 2);
        QCOMPARE(model.getLastAssistantMessage(), QString("two"));
    }

    void togglePinned()
    {
        ConversationModel model;
        model.addUserMessage("pin me");
        model.togglePinned(0);
        QCOMPARE(model.toJsonArray().at(0).toObject()["pinned"].toBool(), true);
        model.togglePinned(0);
        QCOMPARE(model.toJsonArray().at(0).toObject()["pinned"].toBool(), false);
        model.togglePinned(42);  // out of range: no crash
    }

    void imagePathRoundTrip()
    {
        ConversationModel model;
        model.addUserMessage("look at this", "/tmp/photo.jpg");
        QCOMPARE(model.toJsonArray().at(0).toObject()["imagePath"].toString(),
                 QString("/tmp/photo.jpg"));

        // API payload only carries role and content
        QVariantList api = model.getMessagesForApi().toList();
        QCOMPARE(api.count(), 1);
        QVERIFY(!api.at(0).toMap().contains("imagePath"));
        QCOMPARE(api.at(0).toMap()["content"].toString(), QString("look at this"));
    }

    void lastAssistantSkipsEmpty()
    {
        ConversationModel model;
        model.addUserMessage("q1");
        model.addAssistantMessage("first answer");
        model.addUserMessage("q2");
        model.addAssistantMessage("");
        QCOMPARE(model.getLastAssistantMessage(), QString("first answer"));
    }
};

class TestMistralAPI : public QObject
{
    Q_OBJECT

private slots:
    void streamingDelta()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));

        api.processStreamData("data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n");
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QString("Hello"));
    }

    void utf8SplitAcrossChunks()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));

        QByteArray line = QString::fromUtf8("data: {\"choices\":[{\"delta\":{\"content\":\"caf\xC3\xA9\"}}]}\n").toUtf8();
        // Split in the middle of the two-byte e-acute sequence
        int cut = line.indexOf("\xC3") + 1;
        api.processStreamData(line.left(cut));
        QCOMPARE(spy.count(), 0);  // incomplete line buffered
        api.processStreamData(line.mid(cut));
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QString::fromUtf8("caf\xC3\xA9"));
    }

    void doneMarkerIgnored()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));
        api.processStreamData("data: [DONE]\n");
        QCOMPARE(spy.count(), 0);
    }

    void usageChunk()
    {
        MistralAPI api;
        QSignalSpy contentSpy(&api, SIGNAL(streamingResponse(QString)));
        QSignalSpy usageSpy(&api, SIGNAL(usageReceived(int,int)));

        api.processStreamData("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}],"
                              "\"usage\":{\"prompt_tokens\":25,\"completion_tokens\":89,\"total_tokens\":114}}\n");
        QCOMPARE(contentSpy.count(), 0);
        QCOMPARE(usageSpy.count(), 1);
        QCOMPARE(usageSpy.at(0).at(0).toInt(), 25);
        QCOMPARE(usageSpy.at(0).at(1).toInt(), 89);
    }

    void malformedLinesIgnored()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));
        api.processStreamData("garbage\n");
        api.processStreamData("data: {broken json\n");
        api.processStreamData(": comment\n");
        api.processStreamData("\n\n");
        QCOMPARE(spy.count(), 0);
    }

    void multipleLinesOneChunk()
    {
        MistralAPI api;
        QSignalSpy spy(&api, SIGNAL(streamingResponse(QString)));
        api.processStreamData("data: {\"choices\":[{\"delta\":{\"content\":\"a\"}}]}\n"
                              "data: {\"choices\":[{\"delta\":{\"content\":\"b\"}}]}\n"
                              "data: [DONE]\n");
        QCOMPARE(spy.count(), 2);
        QCOMPARE(spy.at(0).at(0).toString(), QString("a"));
        QCOMPARE(spy.at(1).at(0).toString(), QString("b"));
    }
};

class TestConversationManager : public QObject
{
    Q_OBJECT

private slots:
    void saveAndReloadConversation()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        QVERIFY(!id.isEmpty());

        ConversationModel *model = manager.currentConversation();
        model->addUserMessage("hello", "/tmp/img.jpg");
        model->addAssistantMessage("hi");
        model->togglePinned(1);
        manager.saveCurrentConversation();
        manager.updateCurrentConversationTitle("My chat");
        manager.updateCurrentConversationCategory("code");

        // Switch away and back: content must survive the round trip
        manager.createNewConversation();
        manager.loadConversation(id);

        QCOMPARE(manager.currentConversation()->rowCount(), 2);
        QJsonArray json = manager.currentConversation()->toJsonArray();
        QCOMPARE(json.at(0).toObject()["imagePath"].toString(), QString("/tmp/img.jpg"));
        QCOMPARE(json.at(1).toObject()["pinned"].toBool(), true);

        QVariantMap details = manager.getConversationDetails(id).toMap();
        QCOMPARE(details["title"].toString(), QString("My chat"));

        QVariantMap stats = manager.getConversationStatistics(id);
        QCOMPARE(stats["category"].toString(), QString("code"));
        QCOMPARE(stats["messageCount"].toInt(), 2);
    }

    void markdownExport()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        manager.currentConversation()->addUserMessage("What is Qt?");
        manager.currentConversation()->addAssistantMessage("A C++ framework.");
        manager.saveCurrentConversation();
        manager.updateCurrentConversationTitle("Qt question");

        QString md = manager.conversationToMarkdown(id);
        QVERIFY(md.startsWith("# Qt question"));
        QVERIFY(md.contains("## User"));
        QVERIFY(md.contains("What is Qt?"));
        QVERIFY(md.contains("## Assistant"));
        QVERIFY(md.contains("A C++ framework."));

        QCOMPARE(manager.conversationToMarkdown("no-such-id"), QString());
    }

    void pinnedMessagesAcrossConversations()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("pin this");
        manager.currentConversation()->togglePinned(0);
        manager.saveCurrentConversation();

        QVariantList pins = manager.getPinnedMessages();
        QCOMPARE(pins.count(), 1);
        QCOMPARE(pins.at(0).toMap()["content"].toString(), QString("pin this"));
        QCOMPARE(pins.at(0).toMap()["messageIndex"].toInt(), 0);
    }

    void funStatsGhostAndLongest()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        // One abandoned conversation: single user message
        manager.currentConversation()->addUserMessage("abandoned question");
        manager.saveCurrentConversation();

        manager.createNewConversation();
        manager.currentConversation()->addUserMessage(QString(500, 'x'));
        manager.currentConversation()->addAssistantMessage("short reply");
        manager.currentConversation()->addUserMessage("thanks");
        manager.currentConversation()->addAssistantMessage("welcome welcome welcome welcome");
        manager.saveCurrentConversation();

        QVariantMap fun = manager.getFunStats();
        QCOMPARE(fun["ghostCount"].toInt(), 1);
        QCOMPARE(fun["longestUserChars"].toInt(), 500);
        QVERIFY(fun["topWords"].toList().count() > 0);
        QCOMPARE(fun["topWords"].toList().at(0).toMap()["word"].toString(),
                 QString("welcome"));
    }

    void tokenUsageAccumulates()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        QString id = manager.currentConversationId();
        qint64 before = manager.getStatistics()["totalTokens"].toLongLong();

        manager.addTokenUsage(10, 20);
        manager.addTokenUsage(5, 5);
        manager.addTokenUsage(0, 0);  // ignored

        QCOMPARE(manager.getStatistics()["totalTokens"].toLongLong(), before + 40);
        QCOMPARE(manager.getConversationStatistics(id)["totalTokens"].toLongLong(), qint64(40));

        QVariantList perDay = manager.getStatistics()["tokensPerDay"].toList();
        QCOMPARE(perDay.count(), 14);
        QVERIFY(perDay.last().toInt() >= 40);
    }

    void categoryCounting()
    {
        ConversationManager manager;
        manager.purgeAllConversations();

        manager.currentConversation()->addUserMessage("write me a poem");
        manager.saveCurrentConversation();
        manager.updateCurrentConversationCategory("writing");

        QVariantMap counts = manager.getStatistics()["categoryCounts"].toMap();
        QCOMPARE(counts["writing"].toInt(), 1);
    }
};

int main(int argc, char *argv[])
{
    // Redirect QSettings away from the real user configuration
    QTemporaryDir configDir;
    qputenv("XDG_CONFIG_HOME", configDir.path().toUtf8());

    QCoreApplication app(argc, argv);

    int status = 0;
    {
        TestConversationModel t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestMistralAPI t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestConversationManager t;
        status |= QTest::qExec(&t, argc, argv);
    }
    return status;
}

#include "tst_main.moc"
