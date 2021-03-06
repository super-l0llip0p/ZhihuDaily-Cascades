import bb.cascades 1.4
import bb.device 1.4
import tech.lwl 1.0
import "asset:///components"
import "asset:///pages/child"

Page {
    id: root
    actionBarVisibility: ChromeVisibility.Compact
    
    property variant sectionId
    property variant sectionName
    
    property variant currentDate: Qt.formatDate(dateTimePicker.value, "yyyy/MM/dd")
    property variant maximumDate: new Date()
    property variant minimumDate: new Date('2013/05/20')
    property bool dataLoading: false // 是否正在加载数据
    property bool initTimerRunning: true
    property variant lastDate // 用于加载数据参数
    property bool isEnd: false // 是否全部数据已加载
    property bool isRefresh: false // 是否为刷新动作
    property bool isChangeDate: false
    property bool expanded: false
    
    titleBar: TitleBar {
        scrollBehavior: TitleBarScrollBehavior.Sticky
        kind: TitleBarKind.FreeForm
        kindProperties: FreeFormTitleBarKindProperties {
            expandableArea.indicatorVisibility: TitleBarExpandableAreaIndicatorVisibility.Visible
            
            Container {
                layout: StackLayout {
                    orientation: LayoutOrientation.LeftToRight
                }
                leftPadding: ui.du(2)
                
                Label {
                    text: sectionName + "：" + currentDate
                    verticalAlignment: VerticalAlignment.Center
                    textStyle.base: SystemDefaults.TextStyles.TitleText
                }
            }
            expandableArea {
                toggleArea: TitleBarExpandableAreaToggleArea.EntireTitleBar
                
                content: Container {
                    preferredHeight: displayInfo.pixelSize.height
                    leftPadding: ui.du(2)
                    rightPadding: ui.du(2)
                    
                    layout: DockLayout {
                    
                    }
                    
                    DateTimePicker {
                        id: dateTimePicker
                        expanded: root.expanded
                        
                        verticalAlignment: VerticalAlignment.Center
                        title: qsTr("请选择日期")
                        mode: DateTimePickerMode.Date
                        value: { new Date() }
                        maximum: { maximumDate }
                        minimum: { minimumDate }
                        onValueChanged: {
                            root.currentDate = Qt.formatDate(dateTimePicker.value, "yyyy/MM/dd");
                        }
                    }
                }
                
                onExpandedChanged: {
                    root.expanded = expanded;
                }
            }
        }
    }
    
    Container {
        layout: DockLayout {}
        
        // loading box
        Container {
            visible: initTimerRunning
            layout: DockLayout {}
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            background: Color.create(0,0,0,0.2)
            
            ActivityIndicator {
                running: initTimerRunning
                preferredWidth: 100
                preferredHeight: 100
                horizontalAlignment: HorizontalAlignment.Center
                verticalAlignment: VerticalAlignment.Center
            }
        }
        
        ListView {
            visible: !root.expanded
            
            property variant root_: root
            property variant crtDate: root.currentDate
            
            scrollRole: ScrollRole.Main
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            
            attachedObjects: [
                ListScrollStateHandler {
                    onAtEndChanged: {
                        if(atEnd && !isEnd && !dm.isEmpty() && !dataLoading) {
                            common.apiSectionMore(listRequester, sectionId, root.lastDate);
                        }
                    }
                }
            ]
            leadingVisual: RefreshHeader {
                id: refreshHeader
                refreshThreshold: 150
                onRefreshTriggered: {
                    isRefresh = true;
                    common.apiSectionMore(listRequester, sectionId, root.currentDate);
                }
            }
            
            dataModel: ArrayDataModel {
                id: dm
            }
            
            onTriggered: {
                if(indexPath.length === 1) {
                    var itemData = dm.data(indexPath);
                    if(!itemData['__type']) {
                        root_.pushToNewsPage(itemData['id']);
                    }
                }
            }
            
            listItemComponents: [
                ListItemComponent {
                    NewsListItem {
                        listItemData: ListItemData
                        desc: ListItemData['display_date']
                    }
                }
            ]
            onTouch: {
                refreshHeader.onListViewTouch(event);
            }
            eventHandlers: [
                TouchKeyboardHandler {
                    onTouch: {
                        refreshHeader.onListViewTouch(event);
                    }
                }
            ]
            onCrtDateChanged: {
                if(sectionId) {
                    isChangeDate = true;
                    common.apiSectionMore(listRequester, sectionId, currentDate);
                }
            }
        }
    }
    
    onSectionIdChanged: {
        initTimer.start();
    }
    
    attachedObjects: [
        QTimer {
            id: initTimer
            interval: 200
            onTimeout: {
                initTimer.stop();
                root.initTimerRunning = false;
                common.apiSectionMore(listRequester, sectionId, root.currentDate);
            }
        },
        Requester {
            id: listRequester
            onBeforeSend: {
                root.dataLoading = true;
            }
            onFinished: {
                root.dataLoading = false;
                var rt = JSON.parse(data);
                var stories = rt['stories'];
                var isEnd = !stories.length;
                
                common.formatFastImageUrl(stories, 'images', true, true);
                
                if(root.isRefresh || root.isChangeDate) {
                    if(root.isRefresh) {
                        _misc.showToast(qsTr("刷新成功"));
                    }
                    isEnd = false;
                    isRefresh = false;
                    isChangeDate = false;
                    
                    refreshHeader.endRefresh();
                    
                    dm.clear();
                    dm.insert(0, stories);
                }else{
                    dm.append(stories);
                }
                
                root.isEnd = isEnd;
                // 保存最后一条数据的日期
                if(!isEnd) {
                    root.lastDate = stories[stories.length - 1]['date'];
                }
            }
            onError: {
                _misc.showToast(error);
                root.dataLoading = false;
            }
        },
        DisplayInfo {
            id: displayInfo
        },
        ComponentDefinition {
            id: newsPage
            source: "asset:///pages/news.qml"
        }
    ]
    
    function pushToNewsPage(newsId) {
        var page = newsPage.createObject();
        page.newsId = newsId;
        
        nav.push(page);
    }
}
