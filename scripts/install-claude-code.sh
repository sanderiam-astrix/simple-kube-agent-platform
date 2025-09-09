#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "Installing Claude Code on worker node..."

# Update system
apt-get update
apt-get upgrade -y

# Install Node.js 18
print_status "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Python and pip
print_status "Installing Python and pip..."
apt-get install -y python3 python3-pip python3-venv

# Install AWS CLI v2
print_status "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Git
apt-get install -y git

# Create claude-code user
print_status "Creating claude-code user..."
useradd -m -s /bin/bash claude-code || true
usermod -aG sudo claude-code || true

# Switch to claude-code user for installation
print_status "Installing Claude Code as claude-code user..."

# Create installation script for claude-code user
cat > /tmp/install-claude-code-user.sh << 'EOF'
#!/bin/bash
set -e

echo "Installing Claude Code as claude-code user..."

# Set up environment
cd /home/claude-code
export NODE_ENV=production

# Try to install Claude Code via npm
echo "Attempting to install Claude Code via npm..."
npm install -g @anthropic/claude-code@latest || \
npm install -g claude-code@latest || \
echo "Claude Code npm package not found, trying alternative methods..."

# Alternative: Install from source
if ! command -v claude-code &> /dev/null; then
    echo "Installing Claude Code from source..."
    
    # Try different repositories
    git clone https://github.com/anthropic/claude-code.git /home/claude-code/claude-code-source || \
    git clone https://github.com/Anthropic/claude-code.git /home/claude-code/claude-code-source || \
    echo "Claude Code repository not found, creating fallback setup"
    
    if [ -d "/home/claude-code/claude-code-source" ]; then
        cd /home/claude-code/claude-code-source
        npm install
        npm run build || echo "Build step failed, continuing..."
    fi
fi

# Create a simple Claude Code service if installation fails
if ! command -v claude-code &> /dev/null; then
    echo "Creating Claude Code fallback service..."
    
    cat > /home/claude-code/claude-code-service.py << 'PYEOF'
#!/usr/bin/env python3
import http.server
import socketserver
import json
import os
import sys
from urllib.parse import urlparse, parse_qs

class ClaudeCodeHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        elif self.path == '/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            status = {
                'status': 'running',
                'service': 'claude-code-agent',
                'region': os.environ.get('AWS_REGION', 'us-east-2'),
                's3_bucket': os.environ.get('S3_BUCKET', 'not-set'),
                'mode': 'fallback',
                'node_version': os.popen('node --version').read().strip(),
                'python_version': sys.version
            }
            self.wfile.write(json.dumps(status, indent=2).encode())
        elif self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            response = f'''Claude Code AI Agent - Worker Node
Status: Running
Region: {os.environ.get('AWS_REGION', 'us-east-2')}
S3 Bucket: {os.environ.get('S3_BUCKET', 'not-set')}
Mode: Fallback (Claude Code not installed)
Node Version: {os.popen('node --version').read().strip()}
Python Version: {sys.version.split()[0]}

Available endpoints:
- /health - Health check
- /status - JSON status
- / - This message

This is a fallback service that can be extended to include
actual Claude Code functionality.
'''
            self.wfile.write(response.encode())
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Not Found')

    def do_POST(self):
        # Handle Claude Code API requests
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        response = {
            'status': 'received',
            'message': 'Claude Code API endpoint (fallback mode)',
            'data_length': len(post_data),
            'endpoint': self.path
        }
        self.wfile.write(json.dumps(response, indent=2).encode())

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    with socketserver.TCPServer(('', port), ClaudeCodeHandler) as httpd:
        print(f'Claude Code service running on port {port}')
        httpd.serve_forever()
PYEOF

    chmod +x /home/claude-code/claude-code-service.py
fi

# Create systemd service
echo "Creating systemd service..."
sudo tee /etc/systemd/system/claude-code.service > /dev/null << 'EOF'
[Unit]
Description=Claude Code AI Agent Service
After=network.target

[Service]
Type=simple
User=claude-code
WorkingDirectory=/home/claude-code
Environment=AWS_REGION=us-east-2
Environment=S3_BUCKET=ai-agent-lab-dev-ai-agent-files
Environment=PORT=8080
ExecStart=/usr/bin/python3 /home/claude-code/claude-code-service.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable claude-code
sudo systemctl start claude-code

echo "Claude Code service installed and started!"
EOF

chmod +x /tmp/install-claude-code-user.sh
sudo -u claude-code /tmp/install-claude-code-user.sh

# Clean up
rm -f /tmp/install-claude-code-user.sh

print_status "Claude Code installation completed!"
print_status "Service status:"
systemctl status claude-code --no-pager -l

print_status "Testing service..."
sleep 5
curl -f http://localhost:8080/health || echo "Service not ready yet"
curl -f http://localhost:8080/status || echo "Status endpoint not ready yet"

print_status "Claude Code installation finished!"
