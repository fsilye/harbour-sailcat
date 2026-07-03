TARGET = harbour-sailcat

CONFIG += sailfishapp

# Version is passed by the spec file (%qmake5 VERSION=%{version})
isEmpty(VERSION) {
    VERSION = 1.9.6
}
DEFINES += APP_VERSION=\\\"$$VERSION\\\"

SOURCES += src/harbour-sailcat.cpp \
    src/mistralapi.cpp \
    src/conversationmodel.cpp \
    src/conversationmanager.cpp \
    src/settingsmanager.cpp \
    src/updatechecker.cpp

HEADERS += src/mistralapi.h \
    src/conversationmodel.h \
    src/conversationmanager.h \
    src/settingsmanager.h \
    src/updatechecker.h

DISTFILES += qml/harbour-sailcat.qml \
    qml/cover/CoverPage.qml \
    qml/pages/ChatPage.qml \
    qml/pages/ConversationListPage.qml \
    qml/pages/ConversationHistoryPage.qml \
    qml/pages/ConversationDetailPage.qml \
    qml/pages/PinnedMessagesPage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/StatsPage.qml \
    qml/components/MessageBubble.qml \
    qml/components/ModelSelector.qml \
    qml/components/TypingIndicator.qml \
    qml/components/CountUpLabel.qml \
    qml/components/RatioDonut.qml \
    rpm/harbour-sailcat.spec \
    harbour-sailcat.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n

TRANSLATIONS += translations/harbour-sailcat-en.ts \
                translations/harbour-sailcat-fr.ts \
                translations/harbour-sailcat-de.ts \
                translations/harbour-sailcat-es.ts \
                translations/harbour-sailcat-fi.ts \
                translations/harbour-sailcat-it.ts
