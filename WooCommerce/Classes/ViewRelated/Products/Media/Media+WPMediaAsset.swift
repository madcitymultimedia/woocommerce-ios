import MobileCoreServices
import WPMediaPicker
import Yosemite

extension CancellableMedia: WPMediaAsset {
    public func image(with size: CGSize, completionHandler: @escaping WPMediaImageBlock) -> WPMediaRequestID {
        let imageURL = media.thumbnailURL ?? media.src
        guard let encodedString = imageURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedString) else {
            return 0
        }

        // TODO-2073: move image fetching to `WordPressMediaLibraryPickerDataSource` instead of having to use the `ServiceLocator` singleton on a `Media`
        // extension.
        let imageService = ServiceLocator.imageService
        imageService.retrieveImageFromCache(with: url) { [weak self] (image) in
            if let image = image {
                completionHandler(image, nil)
                return
            }

            self?.cancellableTask = imageService.downloadImage(with: url, shouldCacheImage: true) { (image, error) in
                completionHandler(image, error)
            }
        }
        return Int32(media.mediaID)
    }

    public func cancelImageRequest(_ requestID: WPMediaRequestID) {
        cancellableTask?.cancel()
    }

    public func videoAsset(completionHandler: @escaping WPMediaAssetBlock) -> WPMediaRequestID {
        fatalError("Video is not supported")
    }

    public func assetType() -> WPMediaType {
        return media.mediaType.toWPMediaType
    }

    public func duration() -> TimeInterval {
        fatalError("Video is not supported")
    }

    public func baseAsset() -> Any {
        return self
    }

    public func identifier() -> String {
        return "\(media.mediaID)"
    }

    public func date() -> Date {
        return media.date
    }

    public func pixelSize() -> CGSize {
        guard let height = media.height, let width = media.width else {
            return .zero
        }
        return CGSize(width: width, height: height)
    }

    public func filename() -> String? {
        return media.filename
    }

    public func fileExtension() -> String? {
        return media.fileExtension
    }
}
