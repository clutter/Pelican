# Pelican

![Build Status](https://img.shields.io/bitrise/d51fabc085778510/master.svg?token=g2yID499WygOMM7DxSKtQQ)
[![Version](https://img.shields.io/cocoapods/v/Pelican.svg)](http://cocoapods.org/pods/Pelican)
[![License](https://img.shields.io/cocoapods/l/Pelican.svg)](http://cocoapods.org/pods/Pelican)
[![Platform](https://img.shields.io/cocoapods/p/Pelican.svg)](http://cocoapods.org/pods/Pelican)

Pelican is a persisted batching library useful for log rolling, event logging or doing other periodic background processing.

## Example

The following is an example of setting up custom event logging, for example to your own API using Pelican to batch upload tasks.

```swift
protocol AppEvents: PelicanGroupable {
    var eventName: String { get }
    var timeStamp: Date { get }
}

// Batch all app events together into the same group
extension AppEvents {
    // Used to group events so they can batched
    var group: String {
        return "Example App Events"
    }

    /// Pelican will call `processGroup` on a background thread. You should implement it to do whatever processing is 
    /// relevant to your application. Below is a sample implementation that sends application events to as a batch.
    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void)) {
        // In this case, we'll create JSON from tasks and send it to our API.
        let json = tasks.map { $0.dictionary }
        API.shared.postEvents(json: json) { error in
            if error == nil {
                didComplete(PelicanProcessResult.done)
            } else {
                // Retry will call process group again until succesful
                didComplete(PelicanProcessResult.retry(delay: 0))
            }
        }
    }
}

struct LogInEvent: PelicanBatchableTask, AppEvents {
    let eventName: String = "Log In"
    let timeStamp: Date
    let userName: String

    init(userName: String) {
        self.timeStamp = Date()
        self.userName = userName
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: LogInEvent.self)

    init?(dictionary: [String : Any]) {
        guard let timeStamp = dictionary["timeStamp"] as? Date,
            let userName = dictionary["userName"] as? String else {
                return nil
        }
        self.timeStamp = timeStamp
        self.userName = userName
    }

    var dictionary: [String : Any] {
        return [
            "timeStamp": timeStamp,
            "userName": userName
        ]
    }
}
```

Register your batchable tasks as soon as possible, for example in ```application(_ application: UIApplication, didFinishLaunchingWithOptions...```

```swift
Pelican.register(tasks: [LogInEvent.self])
```

When the user performs an event we log it with Pelican, after 5 seconds events are grouped and ```processGroup``` is called to send them.

```swift
Pelican.shared.gulp(task: LogInEvent(userName: "Ender Wiggin"))
```

## Requirements

## Installation

Pelican is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Pelican"
```

## Author

bd755bf4f7e672000cab58c4b721a8cdbe22a839, robmanson@gmail.com

## License

Pelican is available under the MIT license. See the LICENSE file for more info.
