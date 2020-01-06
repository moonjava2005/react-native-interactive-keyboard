import {Keyboard, Platform,} from 'react-native';
import TextInputKeyboardMangerIOS from '../TextInputKeyboardMangerIOS';


export default class KeyboardUtils {
    static dismiss = () => {
        Keyboard.dismiss();
        if (Platform.OS === 'ios') {
            TextInputKeyboardMangerIOS.dismissKeyboard();
        }
    };
}
