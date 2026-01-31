# FORAI Analytics Headers - 2025-07-20T03:17:57.580664
# Agent: claude-code
# Session: unified_20250720_031757_807434
# Context: Systematic FORAI header application - Shell scripts batch
# File: claude_context_bridge.sh
# Auto-tracking: Enabled
# Memory-integrated: True

#!/bin/bash

# Claude Context Bridge - Share context between CLI and Telegram bot
# Version: 1.0

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Optional: Configure Telegram bot directory if you have claude-code-telegram installed
readonly TELEGRAM_BOT_DIR="${TELEGRAM_BOT_DIR:-$HOME/claude-code-telegram}"
readonly CONTEXT_SHARE_DIR="/tmp/claude-context-bridge"
readonly CLI_SESSIONS_DIR="$HOME/.claude"
readonly BOT_DB_PATH="$TELEGRAM_BOT_DIR/data/bot.db"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [Context-Bridge] $*"
}

# Initialize bridge directories
init_bridge() {
    log "🔧 Initializing Claude Context Bridge..."
    
    mkdir -p "$CONTEXT_SHARE_DIR"
    mkdir -p "$CONTEXT_SHARE_DIR/exports"
    mkdir -p "$CONTEXT_SHARE_DIR/imports"
    mkdir -p "$CONTEXT_SHARE_DIR/metadata"
    
    log "✅ Bridge directories created"
}

# Export current Claude CLI session context
export_cli_context() {
    local export_name="${1:-cli-context-$(date +%Y%m%d_%H%M%S)}"
    local export_file="$CONTEXT_SHARE_DIR/exports/${export_name}.json"
    
    log "📤 Exporting CLI context to: $export_name"
    
    # Capture current working directory and conversation state
    local current_dir=$(pwd)
    local conversation_history=""
    
    # Try to extract conversation from Claude CLI memory
    if [ -d "$CLI_SESSIONS_DIR" ]; then
        # Find recent Claude session files
        local recent_session=$(find "$CLI_SESSIONS_DIR" -name "*.json" -o -name "*.md" 2>/dev/null | head -1)
        if [ -n "$recent_session" ]; then
            conversation_history="Found CLI session: $recent_session"
        fi
    fi
    
    # Create context export
    cat > "$export_file" << EOF
{
    "export_type": "claude_cli_context",
    "timestamp": "$(date -Iseconds)",
    "source": "claude_cli",
    "session_id": "$export_name",
    "metadata": {
        "working_directory": "$current_dir",
        "export_time": "$(date)",
        "user": "$(whoami)",
        "hostname": "$(hostname)"
    },
    "conversation": {
        "history_note": "$conversation_history",
        "current_project": "$current_dir",
        "project_files": $(find "$current_dir" -maxdepth 2 -type f -name "*.py" -o -name "*.js" -o -name "*.md" -o -name "*.sh" 2>/dev/null | head -20 | jq -R . | jq -s . || echo '[]'),
        "recent_commands": "$(history | tail -10 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//' || echo 'No recent commands')"
    },
    "context_summary": "Current CLI session context including working directory: $current_dir",
    "instructions_for_bot": "This context was exported from Claude CLI. The user wants to continue this conversation in Telegram bot. Current working directory and project context should be maintained."
}
EOF

    # Create metadata file
    cat > "$CONTEXT_SHARE_DIR/metadata/${export_name}.meta" << EOF
TYPE=cli_export
TIMESTAMP=$(date +%s)
WORKING_DIR=$current_dir
STATUS=ready_for_import
EOF

    log "✅ CLI context exported successfully"
    log "📁 Export file: $export_file"
    
    echo "$export_file"
}

# Import context to Telegram bot
import_to_telegram() {
    local export_file="$1"
    local user_id="${2:-12345}"  # Default test user ID
    
    log "📥 Importing context to Telegram bot..."
    
    if [ ! -f "$export_file" ]; then
        log "❌ Export file not found: $export_file"
        return 1
    fi
    
    # Check if bot database exists
    if [ ! -f "$BOT_DB_PATH" ]; then
        log "❌ Bot database not found: $BOT_DB_PATH"
        log "💡 Make sure Telegram bot is initialized"
        return 1
    fi
    
    # Extract context data
    local context_data=$(cat "$export_file")
    local working_dir=$(echo "$context_data" | jq -r '.metadata.working_directory')
    local context_summary=$(echo "$context_data" | jq -r '.context_summary')
    
    # Create import script for bot
    local import_script="$CONTEXT_SHARE_DIR/import_to_bot.py"
    cat > "$import_script" << 'EOF'
#!/usr/bin/env python3
import sys
import json
import sqlite3
from datetime import datetime
from pathlib import Path

def import_context_to_bot(db_path, export_file, user_id):
    """Import CLI context into Telegram bot database."""
    
    # Load export data
    with open(export_file, 'r') as f:
        context_data = json.load(f)
    
    # Connect to bot database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Create a new session with imported context
        session_id = f"imported_{context_data['session_id']}"
        now = datetime.utcnow().isoformat()
        
        # Insert into sessions table (if exists)
        try:
            cursor.execute("""
                INSERT OR REPLACE INTO sessions 
                (session_id, user_id, project_path, created_at, last_used, message_count, total_turns)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                session_id,
                user_id,
                context_data['metadata']['working_directory'],
                now,
                now,
                1,  # message_count
                1   # total_turns
            ))
            print(f"✅ Session {session_id} created in bot database")
        except sqlite3.Error as e:
            print(f"⚠️ Could not create session: {e}")
        
        # Add context message to conversation history
        try:
            context_message = f"""🔄 **Context Imported from Claude CLI**

📁 **Working Directory:** `{context_data['metadata']['working_directory']}`
⏰ **Export Time:** {context_data['metadata']['export_time']}
🖥️ **Host:** {context_data['metadata']['hostname']}

📋 **Context Summary:**
{context_data['context_summary']}

💡 **Instructions:**
{context_data['instructions_for_bot']}

🗂️ **Project Files:**
{chr(10).join(context_data['conversation']['project_files'][:10])}

---
*Context successfully imported. Continue conversation below...*
"""
            
            # Try to insert into messages/conversations table
            cursor.execute("""
                INSERT INTO conversation_history 
                (session_id, user_id, message, message_type, timestamp)
                VALUES (?, ?, ?, ?, ?)
            """, (
                session_id,
                user_id,
                context_message,
                'system',
                now
            ))
            print(f"✅ Context message added to conversation history")
            
        except sqlite3.Error as e:
            print(f"⚠️ Could not add context message: {e}")
            # Try alternative table structure
            try:
                cursor.execute("""
                    INSERT INTO messages 
                    (session_id, user_id, content, created_at)
                    VALUES (?, ?, ?, ?)
                """, (session_id, user_id, context_message, now))
                print(f"✅ Context message added to messages table")
            except sqlite3.Error as e2:
                print(f"⚠️ Alternative insert failed: {e2}")
        
        conn.commit()
        print(f"💾 Changes committed to database")
        
    except Exception as e:
        print(f"❌ Import failed: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python import_to_bot.py <db_path> <export_file> <user_id>")
        sys.exit(1)
    
    db_path, export_file, user_id = sys.argv[1:]
    import_context_to_bot(db_path, export_file, int(user_id))
EOF

    # Run the import
    if command -v python3 >/dev/null 2>&1; then
        python3 "$import_script" "$BOT_DB_PATH" "$export_file" "$user_id"
    else
        log "❌ Python3 not found. Cannot import to bot database."
        return 1
    fi
    
    log "✅ Context import completed"
}

# Export from Telegram bot to CLI
export_from_telegram() {
    local user_id="${1:-12345}"
    local session_id="${2:-latest}"
    local export_name="telegram-export-$(date +%Y%m%d_%H%M%S)"
    local export_file="$CONTEXT_SHARE_DIR/exports/${export_name}.json"
    
    log "📤 Exporting from Telegram bot (User: $user_id, Session: $session_id)"
    
    if [ ! -f "$BOT_DB_PATH" ]; then
        log "❌ Bot database not found: $BOT_DB_PATH"
        return 1
    fi
    
    # Create export script
    local export_script="$CONTEXT_SHARE_DIR/export_from_bot.py"
    cat > "$export_script" << 'EOF'
#!/usr/bin/env python3
import sys
import json
import sqlite3
from datetime import datetime

def export_from_bot(db_path, user_id, session_id, output_file):
    """Export conversation from Telegram bot database."""
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Get session info
        if session_id == "latest":
            cursor.execute("""
                SELECT session_id, project_path, created_at, last_used 
                FROM sessions 
                WHERE user_id = ? 
                ORDER BY last_used DESC 
                LIMIT 1
            """, (user_id,))
        else:
            cursor.execute("""
                SELECT session_id, project_path, created_at, last_used 
                FROM sessions 
                WHERE user_id = ? AND session_id = ?
            """, (user_id, session_id))
        
        session_data = cursor.fetchone()
        if not session_data:
            print(f"❌ No session found for user {user_id}")
            return
        
        session_id, project_path, created_at, last_used = session_data
        
        # Get conversation history
        conversation_history = []
        try:
            cursor.execute("""
                SELECT message, message_type, timestamp 
                FROM conversation_history 
                WHERE session_id = ? 
                ORDER BY timestamp ASC
            """, (session_id,))
            conversation_history = [
                {
                    "message": row[0],
                    "type": row[1],
                    "timestamp": row[2]
                }
                for row in cursor.fetchall()
            ]
        except sqlite3.Error:
            # Try alternative table
            try:
                cursor.execute("""
                    SELECT content, 'user' as type, created_at 
                    FROM messages 
                    WHERE session_id = ? 
                    ORDER BY created_at ASC
                """, (session_id,))
                conversation_history = [
                    {
                        "message": row[0],
                        "type": row[1],
                        "timestamp": row[2]
                    }
                    for row in cursor.fetchall()
                ]
            except sqlite3.Error as e:
                print(f"⚠️ Could not retrieve conversation: {e}")
        
        # Create export data
        export_data = {
            "export_type": "telegram_bot_context",
            "timestamp": datetime.utcnow().isoformat(),
            "source": "telegram_bot",
            "session_id": session_id,
            "metadata": {
                "user_id": user_id,
                "project_path": project_path,
                "created_at": created_at,
                "last_used": last_used,
                "conversation_count": len(conversation_history)
            },
            "conversation": {
                "history": conversation_history,
                "project_path": project_path
            },
            "context_summary": f"Telegram bot conversation exported. Project: {project_path}, Messages: {len(conversation_history)}",
            "instructions_for_cli": f"This context was exported from Telegram bot. Continue conversation in CLI. Working directory should be: {project_path}"
        }
        
        # Save export
        with open(output_file, 'w') as f:
            json.dump(export_data, f, indent=2)
        
        print(f"✅ Exported {len(conversation_history)} messages from session {session_id}")
        print(f"📁 Export saved to: {output_file}")
        
    except Exception as e:
        print(f"❌ Export failed: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python export_from_bot.py <db_path> <user_id> <session_id> <output_file>")
        sys.exit(1)
    
    db_path, user_id, session_id, output_file = sys.argv[1:]
    export_from_bot(db_path, int(user_id), session_id, output_file)
EOF

    # Run the export
    if command -v python3 >/dev/null 2>&1; then
        python3 "$export_script" "$BOT_DB_PATH" "$user_id" "$session_id" "$export_file"
    else
        log "❌ Python3 not found. Cannot export from bot database."
        return 1
    fi
    
    echo "$export_file"
}

# Show available exports
list_exports() {
    log "📋 Available context exports:"
    echo ""
    
    if [ -d "$CONTEXT_SHARE_DIR/exports" ]; then
        for export_file in "$CONTEXT_SHARE_DIR/exports"/*.json; do
            if [ -f "$export_file" ]; then
                local filename=$(basename "$export_file")
                local size=$(du -h "$export_file" | cut -f1)
                local date=$(stat -c %y "$export_file" | cut -d. -f1)
                
                echo "📄 $filename ($size) - $date"
                
                # Show summary if available
                if command -v jq >/dev/null 2>&1; then
                    local summary=$(jq -r '.context_summary' "$export_file" 2>/dev/null || echo "No summary")
                    echo "   💡 $summary"
                fi
                echo ""
            fi
        done
    else
        echo "  No exports found"
    fi
}

# Create desktop integration
create_desktop_integration() {
    log "🖥️ Creating desktop integration..."
    
    # Create desktop file for quick context export
    cat > "$HOME/.local/share/applications/claude-context-export.desktop" << EOF
[Desktop Entry]
Name=📤 Export Claude Context
Comment=Export current Claude CLI context for Telegram bot
Exec=gnome-terminal -- bash -c "$SCRIPT_DIR/claude_context_bridge.sh export-quick; read -p 'Press Enter to close...'"
Icon=document-export
Type=Application
Categories=Development;Utility;
EOF

    # Create desktop file for import
    cat > "$HOME/.local/share/applications/claude-context-import.desktop" << EOF
[Desktop Entry]
Name=📥 Import Claude Context
Comment=Import context from Telegram bot to CLI
Exec=gnome-terminal -- bash -c "$SCRIPT_DIR/claude_context_bridge.sh import-latest; read -p 'Press Enter to close...'"
Icon=document-import
Type=Application
Categories=Development;Utility;
EOF

    log "✅ Desktop integration created"
}

# Quick export with notification
export_quick() {
    local export_file=$(export_cli_context)
    
    # Show notification if available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Claude Context Bridge" "CLI context exported successfully!" -t 3000
    fi
    
    log "🚀 Quick export completed: $(basename "$export_file")"
    log "💡 Use 'import' command in Telegram bot to import this context"
}

# Import latest export
import_latest() {
    local latest_export=$(ls -t "$CONTEXT_SHARE_DIR/exports"/*.json 2>/dev/null | head -1)
    
    if [ -n "$latest_export" ]; then
        import_to_telegram "$latest_export"
        
        if command -v notify-send >/dev/null 2>&1; then
            notify-send "Claude Context Bridge" "Context imported to Telegram bot!" -t 3000
        fi
    else
        log "❌ No exports found to import"
    fi
}

# Show bridge status
show_status() {
    echo "🌉 Claude Context Bridge Status"
    echo "==============================="
    echo ""
    
    echo "📁 Bridge Directory: $CONTEXT_SHARE_DIR"
    echo "🤖 Telegram Bot DB: $BOT_DB_PATH"
    echo "🖥️ CLI Sessions: $CLI_SESSIONS_DIR"
    echo ""
    
    echo "📊 Statistics:"
    local export_count=$(find "$CONTEXT_SHARE_DIR/exports" -name "*.json" 2>/dev/null | wc -l)
    echo "  Exports available: $export_count"
    
    if [ -f "$BOT_DB_PATH" ]; then
        echo "  ✅ Telegram bot database accessible"
    else
        echo "  ❌ Telegram bot database not found"
    fi
    
    echo ""
    list_exports
}

# Main menu
main() {
    init_bridge
    
    case "${1:-}" in
        "export")
            export_cli_context "${2:-}"
            ;;
        "export-quick")
            export_quick
            ;;
        "import")
            import_to_telegram "${2:-}" "${3:-12345}"
            ;;
        "import-latest")
            import_latest
            ;;
        "export-from-bot")
            export_from_telegram "${2:-12345}" "${3:-latest}"
            ;;
        "list")
            list_exports
            ;;
        "status")
            show_status
            ;;
        "install")
            create_desktop_integration
            ;;
        *)
            echo "🌉 Claude Context Bridge"
            echo "Usage: $0 {export|import|export-from-bot|list|status|install}"
            echo ""
            echo "Commands:"
            echo "  export [name]           - Export current CLI context"
            echo "  export-quick           - Quick export with notification"
            echo "  import <file> [user_id] - Import context to Telegram bot"
            echo "  import-latest          - Import latest export"
            echo "  export-from-bot [user] [session] - Export from bot to CLI"
            echo "  list                   - List available exports"
            echo "  status                 - Show bridge status"
            echo "  install                - Install desktop integration"
            echo ""
            show_status
            ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi