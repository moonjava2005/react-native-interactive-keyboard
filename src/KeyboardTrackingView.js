/**
 * Created by artald on 15/05/2016.
 */

import React, {Component} from 'react';
import ReactNative, {requireNativeComponent, NativeModules} from 'react-native';

const NativeKeyboardTrackingView = requireNativeComponent('KeyboardTrackingView', null);
const KeyboardTrackingViewManager = NativeModules.KeyboardTrackingViewManager;

export default class KeyboardTrackingView extends Component {

    _trackingViewRef = React.createRef();

    render() {
        return (
            <NativeKeyboardTrackingView
                {...this.props}
                ref={this._trackingViewRef}
            />
        );
    }

    async getNativeProps() {
        if (this._trackingViewRef.current && KeyboardTrackingViewManager && KeyboardTrackingViewManager.getNativeProps) {
            return await KeyboardTrackingViewManager.getNativeProps(ReactNative.findNodeHandle(this._trackingViewRef.current));
        }
        return {};
    }

    scrollToStart() {
        if (this._trackingViewRef.current && KeyboardTrackingViewManager && KeyboardTrackingViewManager.scrollToStart) {
            KeyboardTrackingViewManager.scrollToStart(ReactNative.findNodeHandle(this._trackingViewRef.current));
        }
    }
}
