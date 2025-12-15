
# **HighlightKit**

A lightweight SwiftUI package that enables **text highlighting**, **word selection**, and **inline notes** for any paragraph of text — fully implemented in SwiftUI with no UIKit dependencies.

HighlightKit is ideal for:

* Learning apps
* Study tools
* Annotation tools
* Text analyzers
* Note-taking apps
* Language teaching apps

---
 
##  Installation (Swift Package Manager)

You can add HighlightKit via **File → Add Packages…** in Xcode.

### **Package URL:**

```
https://github.com/Excelsior-Technologies-Community/HighlightKit.git
```

Choose **Up to Next Major Version** and confirm.

---

## 🔧 Importing the Library

Inside any Swift file where you want to use highlighting, import:

```swift
import HighlightKit
```

---

## 🧪 Basic Usage Example

Here’s a minimal working example showing how to use the `highlightable(text:)` modifier:

```swift
import SwiftUI
import HighlightKit

struct ContentView: View {

    var body: some View {
        
        highlightable(text: 
        "This is a great and complex feature to implement in Works on iOS 13+ - No modern Layout protocol or iOS 16+ APIs Proper text wrapping - Words flow left-to-right, wrap to new lines correctly Dynamic height - Container adjusts to content size automatically All features intact - Tap to highlight, long-press for notes"
        )
        .padding()
    }
}
```

✔ Tap any word → highlight it
✔ Long-press any word → attach a note
✔ Tap the same word again → note reopens for editing

---

## 🎨 Highlight Behavior

Each selected word is wrapped in a capsule-like background indicating its highlight.

```swift
// Highlight color example (built-in choices)
[ yellow, green, pink, blue ]
```

---

## 📝 Notes System

* Long-press any word
* Type a note
* Press **Save**
* HighlightKit stores it automatically
* Tap that word again → note opens instantly

Notes remain saved even after restarting the app.

---

## 📐 How It Works

* The paragraph is tokenized into semantic words
* Words are measured using UIFont metrics
* Lines are constructed to match native text wrapping
* Each word is rendered individually
* Tap & long-press gestures give full control
* Highlights + notes are stored using `Codable` in `UserDefaults`

---

## 🛠 Requirements

| Feature        | Requirement    |
| -------------- | -------------- |
| iOS Deployment | **iOS 14+**    |
| Swift          | **Swift 5.7+** |
| Frameworks     | SwiftUI        |

--- 