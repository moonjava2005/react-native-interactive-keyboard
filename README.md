
# react-native-interactive-keyboard

## Getting started

`$ npm install react-native-interactive-keyboard --save`

### Mostly automatic installation

`$ react-native link react-native-interactive-keyboard`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-interactive-keyboard` and add `RNInteractiveKeyboard.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNInteractiveKeyboard.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import info.moonjava.RNInteractiveKeyboardPackage;` to the imports at the top of the file
  - Add `new RNInteractiveKeyboardPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-interactive-keyboard'
  	project(':react-native-interactive-keyboard').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-interactive-keyboard/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-interactive-keyboard')
  	```

#### Windows
[Read it! :D](https://github.com/ReactWindows/react-native)

1. In Visual Studio add the `RNInteractiveKeyboard.sln` in `node_modules/react-native-interactive-keyboard/windows/RNInteractiveKeyboard.sln` folder to their solution, reference from their app.
2. Open up your `MainPage.cs` app
  - Add `using Interactive.Keyboard.RNInteractiveKeyboard;` to the usings at the top of the file
  - Add `new RNInteractiveKeyboardPackage()` to the `List<IReactPackage>` returned by the `Packages` method


## Usage
```javascript
import RNInteractiveKeyboard from 'react-native-interactive-keyboard';

// TODO: What to do with the module?
RNInteractiveKeyboard;
```
  