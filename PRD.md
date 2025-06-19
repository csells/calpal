# CalPal Calendar Chat App PRD

## Overview
A Flutter-based chat application that enables natural language interaction with
Google Calendar using the `flutter_ai_toolkit` and `flutter_ai_providers`
packages, specifically the `LlmChatView` and the `DartanticProvider`.

## Core Components

### 1. Dependencies
- `dartantic_ai`: For Agent and Tool support

### 2. Tool Configuration

#### DateTime Tool
Purpose: Anchor temporal references in the current system time
Name: get-current-date-time
Description: Get the current local date and time in ISO-8601 format

#### Zapier MCP Server
Purpose: Interface with Google Calendar
Configuration:
- Server ID: google-calendar
- Calendar ID: csells@sellsbrothers.com
- URL: Configured via ZAPIER_MCP_URL environment variable

### 3. Agent Configuration
- Model: gemini:gemini-2.5-flash
- System Prompt:
  ```
  You are a helpful calendar assistant.
  
  You have access to tools to get the current date/time and to interact with
  Google Calendar.
  
  Always use the get-current-date-time tool to anchor temporal references like
  "today" and "tomorrow".
  
  The user's primary calendar is csells@sellsbrothers.com.
  ```

### 4. Chat Interface
Provided by `LlmChatView` with:
- Welcome message: "Hi! I can help you manage your calendar. What can I do for you?"
- Example suggestions:
  1. "What's on my schedule today?"
  2. "Schedule a two-hour block for focused work tomorrow."
  3. "Can I skip work and go to the movies tomorrow?"

### 5. Error Handling
- Loading state during agent setup
- Graceful disconnection of MCP server
- Async state management using unawaited where appropriate

### 6. Privacy & Security
- No persistent chat history
- Secure handling of Zapier MCP URL via environment variable (ZAPIER_MCP_URL)
- Private calendar access via csells@sellsbrothers.com

## Implementation Status
- [x] Basic chat interface with LlmChatView
- [x] DateTime Tool integration
- [x] Zapier MCP server connection
- [x] Welcome message and suggestions
- [x] Loading state and error handling
- [x] Proper async resource management