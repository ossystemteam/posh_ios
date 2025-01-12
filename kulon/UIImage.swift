//  Created by Arne Bahlo on 07.06.14.
//  Copyright (c) 2014 Arne Bahlo. All rights reserved.
//
import UIKit
import ImageIO
import Alamofire
import AlamofireImage
import SnapKit
import RxSwift

class KulonImageView: RoundedImageView {
    var currentRequest: DataRequest?
    let activity = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)

    private var disposeBag = DisposeBag()
    public override func setImage(with request: URLRequest) {
        
        cancelRequest()
        
        addSubview(activity)
        activity.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        activity.startAnimating()
        
        currentRequest = Alamofire.request(request).responseData {
            [weak self] response in
            self?.activity.removeFromSuperview()
            if let data = response.result.value {
                if let s = self {
                    
                    UIImage.observableGif(data: data).catchErrorJustReturn(UIImage()).bind(to: s.rx.image).disposed(by: s.disposeBag)
                }
            }
            self?.currentRequest = nil
        }
    }
    
    public func cancelRequest() {
        if let request = currentRequest {
            request.cancel()
        }
    }
}

extension UIImageView {
    
    public func loadGif(name: String) {
        DispatchQueue.global().async {
            let image = UIImage.gif(name: name)
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
    
    public func loadGif(url: URL) {
        DispatchQueue.global().async {
            let image = UIImage.gif(url: url)
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
    
    public func setImage(with request: URLRequest) {
        
         Alamofire.request(request).responseData {
            response in
            if let token = response.response?.allHeaderFields["Authorization"] as? String {
                TokenService().token = token
            }
            if let data = response.result.value {
                self.image = UIImage.gif(data: data)
            }
        }
        
        
    }
    
}

extension UIImage {
    
    public class func observableGif(data: Data) -> Observable<UIImage> {
        return Observable.create({  observer in
            
            DispatchQueue.global().async {
                if let image = gif(data: data) {
                    observer.onNext(image)
                } else {
                    observer.onError(ImageErorr())
                }
            }
            return Disposables.create()
        })
    }
    
    public class func gif(data: Data) -> UIImage? {
        // Create source from data
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            print("SwiftGif: Source for the image does not exist")
            return nil
        }
        
        return UIImage.animatedImageWithSource(source)
    }
    
    public class func gif(urlString: String) -> UIImage? {
        // Validate URL
        guard let bundleURL = URL(string: urlString) else {
            print("SwiftGif: This image named \"\(urlString)\" does not exist")
            return nil
        }
        
        // Validate data
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(urlString)\" into NSData")
            return nil
        }
        
        return gif(data: imageData)
    }
    
    public class func gif(url: URL) -> UIImage? {
        // Validate data
        guard let imageData = try? Data(contentsOf: url) else {
            print("SwiftGif: Cannot turn image named \"\(url)\" into NSData")
            return nil
        }
        return gif(data: imageData)
    }
    
    public class func gif(name: String) -> UIImage? {
        // Check for existance of gif
        guard let bundleURL = Bundle.main
            .url(forResource: name, withExtension: "gif") else {
                print("SwiftGif: This image named \"\(name)\" does not exist")
                return nil
        }
        
        // Validate data
        guard let imageData = try? Data(contentsOf: bundleURL) else {
            print("SwiftGif: Cannot turn image named \"\(name)\" into NSData")
            return nil
        }
        
        return gif(data: imageData)
    }
    
    internal class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        // Get dictionaries
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        let gifPropertiesPointer = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 0)
        if CFDictionaryGetValueIfPresent(cfProperties, Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque(), gifPropertiesPointer) == false {
            return delay
        }
        
        let gifProperties:CFDictionary = unsafeBitCast(gifPropertiesPointer.pointee, to: CFDictionary.self)
        
        // Get delay time
        var delayObject: AnyObject = unsafeBitCast(
            CFDictionaryGetValue(gifProperties,
                                 Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()),
            to: AnyObject.self)
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties,
                                                             Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as? Double ?? 0
        
        if delay < 0.1 {
            delay = 0.1 // Make sure they're not too fast
        }
        
        return delay
    }
    
    internal class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        // Check if one of them is nil
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        // Swap for modulo
        if a! < b! {
            let c = a
            a = b
            b = c
        }
        
        // Get greatest common divisor
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b! // Found it
            } else {
                a = b
                b = rest
            }
        }
    }
    
    internal class func gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    
    internal class func animatedImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [CGImage]()
        var delays = [Int]()
        
        // Fill arrays
        for i in 0..<count {
            // Add image
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }
            
            // At it's delay in cs
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i),
                                                            source: source)
            delays.append(Int(delaySeconds * 700.0)) // Seconds to ms
        }
        
        // Calculate full duration
        let duration: Int = {
            var sum = 0
            
            for val: Int in delays {
                sum += val
            }
            
            return sum
        }()
        
        // Get frames
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            //decodedImage used to force decoding image in bg
            frame = UIImage.decodedImage(with: UIImage(cgImage: images[Int(i)]))
            frameCount = Int(delays[Int(i)] / gcd)
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        // Heyhey
        let animation = UIImage.animatedImage(with: frames,
                                              duration: Double(duration) / 1000.0)
        
        return animation
    }
    
}
