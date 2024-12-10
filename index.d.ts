declare module "react-native" {
  export namespace NativeModules {
    export namespace ReactNativeShareExtension {
      function data(): {
        type: string;
        value: string;
        [name: string]: string;
      }[] | undefined;
      function close(): void;
      function openURL(url: string): void;
    }
  }
}
