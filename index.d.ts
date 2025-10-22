declare module "@ammarahmed/react-native-share-extension" {
  export type ShareItem = {
    type: string;
    value: string;
    name: string;
    size: number;
    [key: string]: any;
  };

  export interface ShareExtensionAPI {
    /**
     * Returns an array of shared items (each item has at least `type` and `value`)
     * or undefined if nothing is available.
     */
    data(): Promise<ShareItem[] | undefined>;

    /** Close the share extension UI. */
    close(): void;

    /** Open the given URL (e.g. for deep links). */
    openURL(url: string): void;
  }

  const ShareExtension: ShareExtensionAPI;
  export default ShareExtension;
}
