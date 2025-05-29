# Fetch

A modern, Swift-native HTTP client library that provides a clean and intuitive API for making network requests. Built with Swift's modern concurrency features, Fetch offers a powerful and type-safe way to interact with web services.

## Features

- 🚀 **Modern Swift Concurrency**: Built with async/await for clean, readable asynchronous code
- 🔒 **Type-Safe**: Strongly typed API for request and response handling
- 📦 **Multiple Response Formats**: Support for JSON, text, and binary data
- 📤 **Flexible Request Options**: Customizable headers, methods, and body content
- 📥 **Streaming Support**: Efficient handling of large responses with streaming
- 🔄 **Download Support**: Built-in support for file downloads
- 🎯 **Cross-Platform**: Works on iOS, macOS, tvOS, and watchOS
- 🔍 **URL Parameter Handling**: Built-in support for URL search parameters
- 📝 **Form Data Support**: Easy handling of multipart/form-data requests

## Requirements

- iOS 13.0+
- macOS 10.15+
- tvOS 13.0+
- watchOS 6.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/grdsdev/Fetch.git", from: "1.0.0")
]
```

## Usage

### Basic GET Request

```swift
import Fetch

// Simple GET request
let response = try await fetch("https://api.example.com/data")
let data = await response.blob()
```

### POST Request with JSON

```swift
import Fetch

// POST request with JSON body
let response = try await fetch(
    "https://api.example.com/data",
    options: FetchOptions(
        method: .post,
        body: ["key": "value"]
    )
)
let json = try await response.json()
```

### Download File

```swift
import Fetch

// Download a file
let response = try await fetch(
    "https://example.com/file.zip",
    options: FetchOptions(download: true)
)
let data = await response.blob()
```

### Working with URL Parameters

```swift
import Fetch

// Create URL with search parameters
var url = URL(string: "https://api.example.com/search")!
url.searchParams.append("query", value: "swift")
url.searchParams.append("page", value: "1")

let response = try await fetch(url)
```

### Form Data Upload

```swift
import Fetch

// Create form data
var formData = FormData()
formData.append("file", fileData, filename: "document.pdf")
formData.append("description", "My document")

// Upload with form data
let response = try await fetch(
    "https://api.example.com/upload",
    options: FetchOptions(
        method: .post,
        body: formData
    )
)
```

### Custom Headers

```swift
import Fetch

// Request with custom headers
let response = try await fetch(
    "https://api.example.com/data",
    options: FetchOptions(
        headers: [
            "Authorization": "Bearer token123",
            "Content-Type": "application/json"
        ]
    )
)
```

## Advanced Usage

### Custom Configuration

```swift
import Fetch

// Create custom Fetch instance with configuration
let customConfig = Fetch.Configuration(
    sessionConfiguration: .ephemeral,
    sessionDelegate: customDelegate
)
let customFetch = Fetch(configuration: customConfig)

// Use custom instance
let response = try await customFetch("https://api.example.com/data")
```

### Response Handling

```swift
import Fetch

let response = try await fetch("https://api.example.com/data")

// Get response as different types
let json: MyModel = try await response.json(decoder: customDecoder)
let text = try await response.text()
let data = await response.blob()
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

