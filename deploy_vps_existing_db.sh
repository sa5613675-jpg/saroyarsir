#!/bin/bash

# VPS Deployment Script for SQLite Production
# Run this on your VPS server at /var/www/saroyarsir

echo "🚀 Starting VPS Deployment..."
echo "================================"

# Stop the service
echo "⏸️  Stopping service..."
sudo systemctl stop saro_vps 2>/dev/null || true

# Pull latest code
echo "📥 Pulling latest code from GitHub..."
git pull origin main

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install flask flask-sqlalchemy flask-bcrypt gunicorn

# Set environment variables
export FLASK_ENV=production
export DATABASE_URL=sqlite:////var/www/saroyarsir/smartgardenhub.db

echo "✅ Using existing database: /var/www/saroyarsir/smartgardenhub.db"
echo "   All existing data will be preserved!"
echo "   All your users, students, batches, exams will remain intact!"

# Set database permissions
echo "🔒 Setting database permissions..."
chmod 644 /var/www/saroyarsir/smartgardenhub.db 2>/dev/null || true

# Copy service file
echo "📋 Copying service file..."
sudo cp saro_vps.service /etc/systemd/system/

# Reload systemd
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

# Start service
echo "▶️  Starting service..."
sudo systemctl start saro_vps

# Enable on boot
echo "🔁 Enabling service on boot..."
sudo systemctl enable saro_vps

# Wait a moment
sleep 2

# Check status
echo ""
echo "================================"
echo "📊 Service Status:"
sudo systemctl status saro_vps --no-pager

echo ""
echo "================================"
echo "✅ Deployment Complete!"
echo ""
echo "🌐 Access your app at: http://$(hostname -I | awk '{print $1}'):8001"
echo ""
echo "🗄️  Using existing database with all your data!"
echo "   Database: /var/www/saroyarsir/smartgardenhub.db"
echo ""
echo "✨ New Features Now Available:"
echo "   ✅ Online Exams (Bangla + Math equations)"
echo "   ✅ Mobile-responsive exam interface"
echo "   ✅ Fee system with 14 columns"
echo "   ✅ SMS templates permanent save"
echo ""
echo "📝 View logs: sudo journalctl -u saro_vps -f"
echo "================================"
