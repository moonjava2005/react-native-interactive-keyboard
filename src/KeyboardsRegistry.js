import React, {PureComponent} from "react";
import {AppRegistry} from 'react-native';
import _ from 'lodash';
import EventEmitterManager from './utils/EventEmitterManager';

const shallowEqual = require('fbjs/lib/shallowEqual');

/*
* Tech debt: how to deal with multiple registries in the app?
*/

const getKeyboardsWithIDs = (keyboardIDs) => {
    return keyboardIDs.map((keyboardId) => {
        return {
            id: keyboardId,
            ...KeyboardRegistry.registeredKeyboards[keyboardId].params,
        };
    });
};

export default class KeyboardRegistry {
    static registeredKeyboards = {};
    static propMap = {};
    static callbackMap = {};
    static eventEmitter = new EventEmitterManager();

    static registerKeyboard = (componentName, getComponentClassFunc, Provider, store) => {
        const InternalComponent = getComponentClassFunc();
        if (store && Provider) {
            const generatorWrapper = function () {
                return class  extends PureComponent {
                    _isMounted = false;

                    constructor(props) {
                        super(props);
                        this.updateProps = this.updateProps.bind(this);
                        this.state = {
                            updateCount: 0
                        }
                    }

                    render() {
                        const {
                            componentId
                        } = this.props;
                        let nextProps = this.props;
                        if (componentId) {
                            const propInMap = KeyboardRegistry.propMap[componentId];
                            if (propInMap) {
                                if (!nextProps) {
                                    nextProps = {}
                                }
                                nextProps = {
                                    ...nextProps,
                                    ...propInMap
                                }
                            }
                        }
                        return (
                            <Provider store={store}>
                                <InternalComponent
                                    {...nextProps}
                                />
                            </Provider>
                        );
                    }

                    componentDidMount() {
                        const {
                            componentId
                        } = this.props;
                        this._isMounted = true;
                        KeyboardRegistry.callbackMap[componentId] = this.updateProps;
                    }

                    componentWillUnmount() {
                        const {
                            componentId
                        } = this.props;
                        this._isMounted = false;
                        if (componentId) {
                            delete KeyboardRegistry.propMap[componentId];
                            delete KeyboardRegistry.callbackMap[componentId];
                        }
                    }

                    updateProps() {
                        if (this._isMounted) {
                            const {
                                updateCount
                            } = this.state;
                            this.setState({
                                updateCount: updateCount + 1
                            })
                        }
                    }
                };
            };
            KeyboardRegistry._registerComponent(componentName, generatorWrapper);
        } else {
            const generatorWrapper = function () {
                return class  extends PureComponent {
                    constructor(props) {
                        super(props);
                        this.updateProps = this.updateProps.bind(this);
                        this.state = {
                            updateCount: 0
                        }
                    }

                    render() {
                        const {
                            componentId
                        } = this.props;
                        let nextProps = this.props;
                        if (componentId) {
                            const propInMap = KeyboardRegistry.propMap[componentId];
                            if (propInMap) {
                                if (!nextProps) {
                                    nextProps = {}
                                }
                                nextProps = {
                                    ...nextProps,
                                    ...propInMap
                                }
                            }
                        }
                        return (
                            <InternalComponent
                                {...nextProps}
                            />
                        );
                    }

                    componentDidMount() {
                        const {
                            componentId
                        } = this.props;
                        this._isMounted = true;
                        KeyboardRegistry.callbackMap[componentId] = this.updateProps;
                    }

                    componentWillUnmount() {
                        const {
                            componentId
                        } = this.props;
                        if (componentId) {
                            delete KeyboardRegistry.propMap[componentId];
                            delete KeyboardRegistry.callbackMap[componentId];
                        }
                    }

                    updateProps() {
                        if (this._isMounted) {
                            const {
                                updateCount
                            } = this.state;
                            this.setState({
                                updateCount: updateCount + 1
                            })
                        }
                    }
                };
            };
            KeyboardRegistry._registerComponent(componentName, generatorWrapper);
        }
    };

    static _registerComponent = (componentName, getComponentFunc, params = {}) => {
        KeyboardRegistry.registeredKeyboards[componentName] = {generator: getComponentFunc, params, componentName};
        AppRegistry.registerComponent(componentName, getComponentFunc, params);
    };


    static getKeyboard = (componentName) => {
        const res = KeyboardRegistry.registeredKeyboards[componentName];
        if (!res || !res.generator) {
            return undefined;
        }
        return res.generator();
    };

    static getKeyboards = (componentIDs = []) => {
        const validKeyboardIDs = _.intersection(componentIDs, Object.keys(KeyboardRegistry.registeredKeyboards));
        return getKeyboardsWithIDs(validKeyboardIDs);
    };

    static getAllKeyboards = () => {
        return getKeyboardsWithIDs(Object.keys(KeyboardRegistry.registeredKeyboards));
    };

    static addListener = (globalID, callback) => {
        KeyboardRegistry.eventEmitter.listenOn(globalID, callback);
    };

    static notifyListeners = (globalID, args) => {
        KeyboardRegistry.eventEmitter.emitEvent(globalID, args);
    };

    static removeListeners = (globalID) => {
        KeyboardRegistry.eventEmitter.removeListeners(globalID);
    };

    static onItemSelected = (globalID, args) => {
        KeyboardRegistry.notifyListeners(`${globalID}.onItemSelected`, args);
    };

    static requestShowKeyboard = (globalID) => {
        KeyboardRegistry.notifyListeners('onRequestShowKeyboard', {keyboardId: globalID});
    };

    static toggleExpandedKeyboard = (globalID) => {
        KeyboardRegistry.notifyListeners('onToggleExpandedKeyboard', {keyboardId: globalID});
    };

    static setProps = (componentId, props) => {
        if (componentId) {
            const prevProps = KeyboardRegistry.propMap[componentId];
            KeyboardRegistry.propMap[componentId] = props;
            if (!shallowEqual((prevProps || null), (props || null))) {
                const callback = KeyboardRegistry.callbackMap[componentId];
                callback && callback();
            }
        }
    }
}
