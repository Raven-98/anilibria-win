import QtQuick 2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import QtMultimedia 5.12
import "../Controls"

Page {
    id: _page
    property bool isFullScreen: false
    property var selectedRelease: null
    property string videoSource: ""
    property var releaseVideos: []
    property var selectedVideo: null
    property bool isFullHdAllowed: false
    property real lastMovedPosition: 0
    property real restorePosition: 0
    property string videoQuality: "sd"
    property string displayVideoPosition: "00:00:00"

    signal navigateFrom()
    signal setReleaseVideo(int releaseId, int seriaOrder)
    signal changeFullScreenMode(bool fullScreen)

    onNavigateFrom: {
        player.pause();
    }
    onSetReleaseVideo: {
        const release = releasesService.getRelease(releaseId);
        if (release) _page.selectedRelease = release;

        const videos = [];
        for (let i = 0; i < _page.selectedRelease.videos.length; i++) {
            const video = _page.selectedRelease.videos[i];
            videos.push({ title: video.title, sd: video.sd, id: video.id, hd: video.hd, fullhd: video.fullhd });
        }
        videos.sort(
            (left, right) => {
                if (left.id === right.id) return 0;
                return left.id > right.id ? 1 : -1;
            }
        );

        _page.releaseVideos = videos;
        const firstVideo = videos[0];
        _page.selectedVideo = firstVideo.id;
        _page.isFullHdAllowed = "fullhd" in firstVideo;
        if (!firstVideo[_page.videoQuality]) _page.videoQuality = "sd";

        _page.videoSource = firstVideo[_page.videoQuality];
        player.play();
    }

    function getZeroBasedDigit(digit) {
        if (digit < 10) return `0${digit}`;
        return `${digit}`;
    }

    anchors.fill: parent

    background: Rectangle {
        color: "black"
    }

    MediaPlayer {
        id: player
        source: _page.videoSource
        autoPlay: false
        onPlaybackStateChanged: {
            playButton.visible = playbackState === MediaPlayer.PausedState || playbackState === MediaPlayer.StoppedState;
            pauseButton.visible = playbackState === MediaPlayer.PlayingState;
        }
        onVolumeChanged: {
            volumeSlider.value = volume * 100;
        }
        onStatusChanged: {
            if (status === MediaPlayer.Buffered && _page.restorePosition > 0) {
                player.seek(_page.restorePosition);
            }
        }

        onPositionChanged: {
            if (!playerLocation.pressed) playerLocation.value = position;

            let seconds = position / 1000;

            const days = Math.floor(seconds / (3600 * 24));
            seconds -= days * 3600 * 24;
            const hours = Math.floor(seconds / 3600);
            seconds -= hours * 3600;
            const minutes = Math.floor(seconds / 60);
            seconds  -= minutes * 60;

            _page.displayVideoPosition = `${getZeroBasedDigit(hours)}:${getZeroBasedDigit(minutes)}:${getZeroBasedDigit(Math.round(seconds))}`;
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (player.playbackState === MediaPlayer.PlayingState) {
                player.pause();
                return;
            }
            if (player.playbackState === MediaPlayer.PausedState || player.playbackState === MediaPlayer.StoppedState) {
                player.play();
            }
        }
        onDoubleClicked: {
            isFullScreen = !isFullScreen;
            changeFullScreenMode(isFullScreen);
        }
    }
    VideoOutput {
        id: videoOutput
        source: player
        anchors.fill: parent
    }

    Rectangle {
        id: seriesPopup
        anchors.top: parent.top
        width: 140
        height: _page.height - controlPanel.height - 20
        color: "transparent"

        Flickable {
            width: seriesPopup.width
            height: seriesPopup.height
            contentWidth: seriesPopup.width
            contentHeight: itemsContent.height
            clip: true

            ScrollBar.vertical: ScrollBar {
                active: true
            }

            Column {
                id: itemsContent
                Repeater {
                    model: _page.releaseVideos
                    delegate: Row {
                        Rectangle {
                            height: 40
                            width: seriesPopup.width
                            color: _page.selectedVideo === modelData.id ? "#64c25656" : "#C8ffffff"
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    _page.selectedVideo = modelData.id;
                                    _page.isFullHdAllowed = "fullhd" in modelData;
                                    _page.videoSource = modelData[_page.videoQuality];
                                    player.play();
                                }
                            }
                            Text {
                                color: _page.selectedVideo === modelData.id ? "white" : "black"
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                text: modelData.title
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: controlPanel
        color: "#82ffffff"
        anchors.bottom: parent.bottom
        width: _page.width
        height: 100

        Column {
            width: controlPanel.width

            Slider {
                id: playerLocation
                height: 20
                width: controlPanel.width
                from: 1
                value: 1
                to: player.duration
                onPressedChanged: {
                    if (!pressed && _page.lastMovedPosition > 0) {
                        player.seek(_page.lastMovedPosition);
                        _page.lastMovedPosition = 0;
                    }
                }

                onMoved: {
                    if (pressed) _page.lastMovedPosition = value;
                }
            }

            Item {
                height: 20
                width: controlPanel.width

                Text {
                    text: _page.displayVideoPosition
                }

                Row {
                    height: 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    ToggleButton {
                        height: 20
                        width: 60
                        text: "1080p"
                        visible: _page.isFullHdAllowed
                        isChecked: _page.videoQuality === `fullhd`
                        onButtonClicked: {
                            _page.videoQuality = `fullhd`;
                            _page.restorePosition = player.position;

                            const video = _page.releaseVideos.find(a => a.id === _page.selectedVideo);

                            _page.videoSource = video[_page.videoQuality];
                            player.play();

                        }
                    }
                    ToggleButton {
                        height: 20
                        width: 60
                        text: "720p"
                        isChecked: _page.videoQuality === `hd`
                        onButtonClicked: {
                            _page.videoQuality = `hd`;
                            _page.restorePosition = player.position;

                            const video = _page.releaseVideos.find(a => a.id === _page.selectedVideo);

                            _page.videoSource = video[_page.videoQuality];
                            player.play();                            
                        }
                    }
                    ToggleButton {
                        height: 20
                        width: 60
                        text: "480p"
                        isChecked: _page.videoQuality === `sd`
                        onButtonClicked: {
                            _page.videoQuality = `sd`;
                            _page.restorePosition = player.position;

                            const video = _page.releaseVideos.find(a => a.id === _page.selectedVideo);

                            _page.videoSource = video[_page.videoQuality];
                            player.play();
                        }
                    }
                }

                Text {
                    height: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    text: "1:00:00"
                }
            }

            Item {
                height: 60
                width: controlPanel.width

                Row {
                    spacing: 5
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    IconButton {
                        width: 40
                        height: 40
                        iconColor: "black"
                        iconPath: "../Assets/Icons/menu.svg"
                        iconWidth: 29
                        iconHeight: 29
                        onButtonPressed: {
                            drawer.open();
                        }
                    }
                    IconButton {
                        width: 40
                        height: 40
                        iconColor: "black"
                        iconPath: "../Assets/Icons/speaker.svg"
                        iconWidth: 24
                        iconHeight: 24
                        onButtonPressed: {
                            player.muted = !player.muted;
                        }
                    }
                    Slider {
                        width: 60
                        height: 40
                        id: volumeSlider
                        from: 0
                        value: 10
                        to: 100
                        onMoved: {
                            player.volume = value / 100;
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    IconButton {
                        width: 40
                        height: 40
                        iconColor: "black"
                        iconPath: "../Assets/Icons/step-backward.svg"
                        iconWidth: 24
                        iconHeight: 24
                        onButtonPressed: {
                            if (_page.selectedVideo === 1) return;

                            _page.selectedVideo--;
                            const video = _page.releaseVideos.find(a => a.id === _page.selectedVideo);
                            _page.isFullHdAllowed = "fullhd" in video;

                            _page.videoSource = _page.releaseVideos[_page.selectedVideo][_page.videoQuality];
                            player.play();
                        }
                    }
                    IconButton {
                        id: playButton
                        width: 40
                        height: 40
                        iconColor: "black"
                        iconPath: "../Assets/Icons/play-button.svg"
                        iconWidth: 24
                        iconHeight: 24
                        onButtonPressed: {
                            player.play();
                        }
                    }
                    IconButton {
                        id: pauseButton
                        width: 40
                        height: 40
                        iconColor: "black"
                        iconPath: "../Assets/Icons/pause.svg"
                        iconWidth: 24
                        iconHeight: 24
                        onButtonPressed: {
                            player.pause();
                        }
                    }
                    IconButton {
                        width: 40
                        height: 40
                        iconColor: "black"
                        iconPath: "../Assets/Icons/step-forward.svg"
                        iconWidth: 24
                        iconHeight: 24
                        onButtonPressed: {
                            if (_page.selectedVideo === _page.releaseVideos.length) return;

                            _page.selectedVideo++;
                            const video = _page.releaseVideos.find(a => a.id === _page.selectedVideo);
                            _page.isFullHdAllowed = "fullhd" in video;

                            _page.videoSource = _page.releaseVideos[_page.selectedVideo][_page.videoQuality];
                            player.play();
                        }
                    }
                }

                Row {
                    spacing: 5
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    IconButton {
                        width: 40
                        height: 40
                        iconColor: "black"
                        iconPath: "../Assets/Icons/resize.svg"
                        iconWidth: 29
                        iconHeight: 29
                        onButtonPressed: {
                            switch (videoOutput.fillMode) {
                                case VideoOutput.PreserveAspectFit:
                                    videoOutput.fillMode = VideoOutput.PreserveAspectCrop;
                                    break;
                                case VideoOutput.PreserveAspectCrop:
                                    videoOutput.fillMode = VideoOutput.PreserveAspectFit;
                                    break;
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        volumeSlider.value = player.volume * 100;
    }
}

