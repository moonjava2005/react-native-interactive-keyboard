import React, {Component} from 'react';
import PropTypes from 'prop-types';
import {findNodeHandle, NativeEventEmitter, NativeModules, processColor, StyleSheet} from 'react-native';
import KeyboardTrackingView from './KeyboardTrackingView';
import CustomKeyboardView from './CustomKeyboardView';
import KeyboardsRegistry from './KeyboardsRegistry';
import _ from 'lodash';


export default class KeyboardAccessoryView extends Component {
    static propTypes = {
        renderContent: PropTypes.func,
        onHeightChanged: PropTypes.func,
        scrollViewRef: PropTypes.any,
        kbInputRef: PropTypes.object,
        kbComponent: PropTypes.string,
        kbInitialProps: PropTypes.object,
        onItemSelected: PropTypes.func,
        onRequestShowKeyboard: PropTypes.func,
        onKeyboardResigned: PropTypes.func,
        iOSScrollBehavior: PropTypes.number,
        revealKeyboardThrottle: PropTypes.number,
        revealKeyboardInteractive: PropTypes.bool,
        manageScrollView: PropTypes.bool,
        requiresSameParentToManageScrollView: PropTypes.bool,
        addBottomView: PropTypes.bool,
        allowHitsOutsideBounds: PropTypes.bool,
        scrollToFocusedInput: PropTypes.bool,
        scrollIsInverted: PropTypes.bool,
        onDismissAccessoryKeyboard: PropTypes.func,
    };
    static defaultProps = {
        iOSScrollBehavior: -1,
        revealKeyboardInteractive: false,
        manageScrollView: true,
        scrollToFocusedInput: false,
        scrollIsInverted: false,
        requiresSameParentToManageScrollView: false,
        addBottomView: false,
        allowHitsOutsideBounds: false,
        revealKeyboardThrottle: 50,
    };

    _isMounted = false;

    constructor(props) {
        super(props);
        this.onContainerComponentHeightChanged = this.onContainerComponentHeightChanged.bind(this);
        this.registerForKeyboardResignedEvent = this.registerForKeyboardResignedEvent.bind(this);

        this.registerForKeyboardResignedEvent();
        this.state = {
            scrollViewNode: null,
            scrollViewRef: null,
            kbComponent: null,
            kbInitialProps: null,
            processedProps: null,
            componentId: _.uniqueId('Keyboard-'),
        };
    }

    static getDerivedStateFromProps(props, state) {
        const {
            kbComponent,
            kbInitialProps,
            scrollViewRef
        } = props;
        let {
            scrollViewNode
        } = state;
        let isDiffRef = false;
        if (state.scrollViewRef !== scrollViewRef) {
            isDiffRef = true;
        } else {
            let _currentRef;
            if (state.scrollViewRef) {
                _currentRef = state.scrollViewRef;
                if (_currentRef.current) {
                    _currentRef = _currentRef.current;
                }
            }
            let _nextRef;
            if (scrollViewRef) {
                _nextRef = scrollViewRef;
                if (_nextRef.current) {
                    _nextRef = _nextRef.current;
                }
            }
            if (_currentRef !== _nextRef) {
                isDiffRef = true;
            }
        }
        if (!scrollViewNode || isDiffRef || kbComponent !== state.kbComponent || kbInitialProps !== state.kbInitialProps) {
            if (!scrollViewNode || isDiffRef) {
                let _nextRef = scrollViewRef;
                if (_nextRef && _nextRef.current !== undefined) {
                    _nextRef = _nextRef.current;
                }
                if (_nextRef) {
                    try {
                        scrollViewNode = findNodeHandle(_nextRef);
                    } catch (e) {
                        scrollViewNode = null;
                    }
                } else {
                    scrollViewNode = null;
                }
            }
            return {
                scrollViewNode: scrollViewNode,
                scrollViewRef: scrollViewRef,
                kbComponent: kbComponent,
                kbInitialProps: kbInitialProps,
                processedProps: processInitialProps(kbInitialProps, kbComponent, state.componentId),
            }
        }
        return null;
    }

    componentWillUnmount() {
        if (this.customInputControllerEventsSubscriber) {
            this.customInputControllerEventsSubscriber.remove();
        }
    }

    onContainerComponentHeightChanged(event) {
        if (this.props.onHeightChanged) {
            this.props.onHeightChanged(event.nativeEvent.layout.height);
        }
    }

    getIOSTrackingScrollBehavior() {
        let scrollBehavior = this.props.iOSScrollBehavior;
        if (NativeModules.KeyboardTrackingViewManager && scrollBehavior === -1) {
            scrollBehavior = NativeModules.KeyboardTrackingViewManager.KeyboardTrackingScrollBehaviorFixedOffset;
        }
        return scrollBehavior;
    }

    registerForKeyboardResignedEvent() {
        let eventEmitter = null;
        if (NativeModules.CustomInputController) {
            eventEmitter = new NativeEventEmitter(NativeModules.CustomInputController);
        }
        if (eventEmitter !== null) {
            this.customInputControllerEventsSubscriber = eventEmitter.addListener('kbdResigned', () => {
                if (this.props.onKeyboardResigned) {
                    this.props.onKeyboardResigned();
                }
            });
        }
    }

    async getNativeProps() {
        if (this.trackingViewRef) {
            return await this.trackingViewRef.getNativeProps();
        }
        return {};
    }

    scrollToStart() {
        if (this.trackingViewRef) {
            this.trackingViewRef.scrollToStart();
        }
    }

    render() {
        const {
            revealKeyboardInteractive,
            manageScrollView,
            requiresSameParentToManageScrollView,
            addBottomView,
            allowHitsOutsideBounds,
            renderContent,
            pointerEvents,
            revealKeyboardThrottle,
            scrollToFocusedInput,
            scrollIsInverted,
            kbInputRef,
            onDismissAccessoryKeyboard,
        } = this.props;
        const {
            scrollViewNode,
            kbComponent,
            processedProps
        } = this.state;
        let inputRef = kbInputRef;
        if (inputRef && inputRef.current) {
            inputRef = inputRef.current;
        }
        return (
            <KeyboardTrackingView
                ref={r => this.trackingViewRef = r}
                scrollViewRef={scrollViewNode}
                style={styles.trackingToolbarContainer}
                onLayout={this.onContainerComponentHeightChanged}
                scrollBehavior={this.getIOSTrackingScrollBehavior()}
                revealKeyboardInteractive={revealKeyboardInteractive}
                scrollToFocusedInput={scrollToFocusedInput}
                scrollIsInverted={scrollIsInverted}
                manageScrollView={manageScrollView}
                requiresSameParentToManageScrollView={requiresSameParentToManageScrollView}
                addBottomView={addBottomView}
                allowHitsOutsideBounds={allowHitsOutsideBounds}
                revealKeyboardThrottle={revealKeyboardThrottle}
                onDismissAccessoryKeyboard={onDismissAccessoryKeyboard}
            >
                {renderContent && renderContent()}
                <CustomKeyboardView
                    inputRef={inputRef}
                    component={kbComponent}
                    initialProps={processedProps}
                    onItemSelected={this.props.onItemSelected}
                    onRequestShowKeyboard={this.props.onRequestShowKeyboard}
                />
            </KeyboardTrackingView>
        );
    }

    componentDidMount() {
        const {
            kbComponent,
            kbInitialProps
        } = this.props;
        this._isMounted = true;

        const {
            componentId
        } = this.state;
        if (kbComponent) {
            const nextComponentId = kbComponent + '-' + componentId;
            KeyboardsRegistry.setProps(nextComponentId, kbInitialProps);
        }
    }

    componentWillUnmount() {
        this._isMounted = false;
    }


    componentDidUpdate(prevProps) {
        const {
            kbComponent,
            kbInitialProps
        } = this.props;
        const {
            componentId
        } = this.state;
        if (kbComponent) {
            const nextComponentId = kbComponent + '-' + componentId;
            KeyboardsRegistry.setProps(nextComponentId, kbInitialProps);
        }
    }
}

function processInitialProps(kbInitialProps, kbComponent, componentId) {
    if (!kbInitialProps) {
        kbInitialProps = {}
    }
    if (kbComponent) {
        kbInitialProps = {
            ...kbInitialProps,
            componentId: kbComponent + '-' + componentId
        };
    }
    if (kbInitialProps && kbInitialProps.backgroundColor) {
        const processedProps = Object.assign({}, kbInitialProps);
        processedProps.backgroundColor = processColor(processedProps.backgroundColor);
        return processedProps;
    }
    return kbInitialProps;
}

const styles = StyleSheet.create({
    trackingToolbarContainer: {
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
    },
});
