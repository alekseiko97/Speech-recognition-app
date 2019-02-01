//
//  ViewController.swift
//  SpeechRecognition
//
//  Created by Moskaljuk Aleksei on 1/25/19.
//  Copyright © 2019 Moskaljuk Aleksei. All rights reserved.
//

import UIKit
import Speech

class ImageViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    // Constants
    let speechRecognizer = SFSpeechRecognizer()
    // A group of connected audio node objects used to generate and process audio signals a and perform audio input and output
    let audioEngine = AVAudioEngine()
    let request = SFSpeechAudioBufferRecognitionRequest()
    
    // Variables
    var authStatus = SFSpeechRecognizer.authorizationStatus()
    var recognitionTask: SFSpeechRecognitionTask?
    
    // Outlets
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    func askPermission() {
        // The authorization status results in changes to the
        // app’s interface, so process the results on the app’s
        // main queue.
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer?.delegate = self
        
        // Make the authorization request
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            // The authorization status results in changes to the
            // app’s interface, so process the results on the app’s
            // main queue.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
    
    func startRecording() {
        // Setup audio engine and speech recognizer
        let node = audioEngine.inputNode
        let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request.append(buffer)
        }
        
        // Prepare and start recording
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("Go ahead, I'm listening")
        } catch {
            return print(error)
        }
        
        // Analyze the speech
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { result, error in
            if let result = result {
                print(result)
                let recognizedText = result.bestTranscription.formattedString
                let tokenizedText = self.tokenizeText(for: recognizedText)
                self.statusLabel.text = recognizedText
                self.manipulateImage(tokenizedText: tokenizedText)
            } else if let error = error {
                print(error)
            }
        })
    }
    
    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        request.endAudio()
    }
    
    func manipulateImage(tokenizedText: [String]) {
        var newImage: UIImage?
        let originalImage = imageView.image
        
        for word in tokenizedText {
            switch word {
            case "Left".lowercased():
                newImage = imageView.image?.rotate(radians: .pi/2)
                self.imageView.image = newImage
            case "Right".lowercased():
                newImage = imageView.image?.rotate(radians: -(.pi/2))
                self.imageView.image = newImage
            // Adjust exposure
            case "Adjust".lowercased():
                let processedImage = applyFilter(to: imageView.image!, filterName: "CIExposureAdjust", value: 0.5)
                self.imageView.image = processedImage
            case "Reset".lowercased():
                self.imageView.image = originalImage
            default:
                return
            }
        }
//
//        UIView.animate(withDuration: 0.1, animations: ({
//
//            self.imageView.transform = CGAffineTransform.init(rotationAngle: 90)
//
//            }))
    }
    
    func applyFilter(to image: UIImage, filterName: String, value: Double) -> UIImage? {
        let context = CIContext(options: nil)
        
        if let filter = CIFilter(name: filterName) {
            let beginImage = CIImage(image: image)
            filter.setValue(beginImage, forKey: kCIInputImageKey)
            filter.setValue(value, forKey: kCIInputEVKey)
            
            if let output = filter.outputImage {
                if let cgImg = context.createCGImage(output, from: output.extent) {
                    let processedImage = UIImage(cgImage: cgImg)
                    return processedImage
                }
            }
        }
        //return UIImage.init()
        return nil
    }
    
    func tokenizeText(for text: String) -> [String] {
        var words = [String]()
        let options: NSLinguisticTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType, .language, .lexicalClass, .nameType, .lemma], options: Int(options.rawValue))
        tagger.string = text
        let range = NSRange.init(location: 0, length: text.utf16.count)
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: options) { tag, tokenRange, stop in
            let word = (text as NSString).substring(with: tokenRange)
            words.append(word)
        }
        
        return words
    }
    
    @IBAction func recordButtonTapped(_ sender: UIButton) {
        if audioEngine.isRunning {
            stopRecording()
            statusLabel.text = "Stopped recording"
            print("Stopped recording")
        } else {
            startRecording()
            statusLabel.text = "Started recording"
            print("Recording has started")
        }
        
    }
    
    @IBAction func leftTapped(_ sender: UIButton) {
        manipulateImage(tokenizedText: ["left"])
    }
    
    @IBAction func rightTapped(_ sender: UIButton) {
        manipulateImage(tokenizedText: ["Right"])
    }
    
}

extension UIImage {
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, true, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}

extension UIView {
    func rotateImage(duration: CFTimeInterval = 1.0, angle: Int, completionDelegate: AnyObject? = nil) {
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(angle)
        rotateAnimation.duration = duration
        
        if let delegate: CAAnimationDelegate = completionDelegate as! CAAnimationDelegate? {
            rotateAnimation.delegate = delegate
        }
        self.layer.add(rotateAnimation, forKey: nil)
    }
}


