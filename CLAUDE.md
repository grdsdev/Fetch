# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fetch is a modern Swift HTTP client library that provides a clean, type-safe API for making network requests. The library is built with Swift's modern concurrency features (async/await) and supports iOS 13.0+, macOS 10.15+, tvOS 13.0+, and watchOS 6.0+ with Swift 6.0+.

## Common Development Commands

### Building and Testing
- **Build the package**: `swift build`
- **Run tests**: `swift test`
- **Build in release mode**: `swift build -c release`
- **Run a specific test**: `swift test --filter TestName`

### Package Management
- **Resolve dependencies**: `swift package resolve`
- **Update dependencies**: `swift package update`
- **Generate Xcode project**: `swift package generate-xcodeproj`

## Architecture Overview

### Core Components

**Fetch Actor (`Sources/Fetch/Fetch.swift:64`)**
- Main entry point for making HTTP requests
- Thread-safe actor that manages URLSession and request lifecycle
- Supports callable syntax: `fetch(url, options: options)`
- Handles different request types: data tasks, upload tasks, and download tasks

**Response System (`Sources/Fetch/Response.swift:7`)**
- `Response` struct contains URL, status, headers, and streaming body
- `Response.Body` is an AsyncSequence that streams data chunks
- Provides convenience methods: `.json()`, `.text()`, `.blob()`
- Supports custom JSONDecoder and JSONEncoder through protocols

**HTTP Headers (`Sources/Fetch/HTTPHeaders.swift:2`)**
- Case-insensitive dictionary for HTTP headers
- Thread-safe with canonical key caching
- Supports subscript access and dictionary literal initialization

**Request Encoding (`Sources/Fetch/Fetch.swift:178`)**
- Automatic content-type detection based on body type
- Supports: Data, String, URL (file upload), FormData, URLSearchParams, Encodable types
- Uses `EncodableWithEncoder` and `DecodableWithDecoder` protocols for custom encoding

### Key Design Patterns

1. **Actor-based Concurrency**: Main Fetch class is an actor for thread safety
2. **Streaming Responses**: Response bodies are AsyncSequence for memory efficiency  
3. **Protocol-based Encoding**: Custom encoding/decoding through protocol conformance
4. **Type-safe HTTP Methods**: HTTPMethod struct with static constants
5. **Configuration-based Setup**: Fetch.Configuration for URLSession customization

### Request Flow

1. `fetch()` function creates URLRequest from URL and FetchOptions
2. Request body is encoded based on type using `encode()` method
3. Appropriate URLSessionTask is created (data/upload/download)
4. DataLoader manages task execution and response streaming
5. Response object provides typed access to response data

### Supporting Files

- **DataLoader**: Manages URLSessionTask execution and delegate handling
- **FormData**: Multipart form data encoding
- **URLSearchParams**: URL query parameter management
- **Codable extensions**: Custom encoding/decoding protocol support