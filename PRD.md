# CalPal Calendar Chat App PRD

## Overview
A Flutter-based chat application that enables natural language interaction with
Google Calendar using the `flutter_ai_toolkit` and `flutter_ai_providers`
packages, specifically the `LlmChatView` and the `DartanticProvider`.

## Core Components

### 1. Dependencies
- `flutter_ai_toolkit`: For LLM integration
- `flutter_ai_providers`: For the DartanticProvider

### 2. Tool Configuration

#### DateTime Tool
Purpose: Anchor temporal references in the current system time Functionality:
- Provides current date/time
- Returns ISO-8601 formatted strings for consistency

#### Zapier MCP Server
Purpose: Interface with Google Calendar Configuration:
- Calendar ID: csells@sellsbrothers.com

Capabilities:
- Read calendar events
- Create new events
- Modify existing events
- Delete events
- Search for specific events

### 3. System Prompt Design
Key elements to include:
- Explicit instruction to use the DateTime Tool for all temporal references
- Clear format for date/time responses
- Specific calendar ID to use

### 4. Chat Interface
Provided by the Flutter AI Toolkit via the `LlmChatView`

### 5. User Interactions

#### Supported Queries
1. Schedule Queries
   - "What's on my schedule today?"
   - "What meetings do I have this afternoon?"
   - "Show me my availability next week"

2. Event Management
   - "Schedule a two-hour block for dartantic tomorrow"
   - "Move my 2pm meeting to 3pm"
   - "Cancel my morning meetings"

3. Complex Queries
   - "Find a free 2-hour block this week for a project review"
   - "When's my next meeting with the Flutter team?"

### 6. Error Handling
- Clear error messages for calendar access issues
- Confirmation requests for destructive actions
- Network connectivity handling

### 7. Privacy & Security
- No storage of chat history (everything is in memory and transient)
- Secure handling of Zapier MCP server URL via an environment variable

## Implementation
- Basic chat interface
- DateTime Tool integration
- Simple calendar queries
- Event creation/modification