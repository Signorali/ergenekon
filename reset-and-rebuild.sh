#!/bin/bash
# Reset and rebuild the entire Ergenekon system

set -e

echo "============================================"
echo "🔄 ERGENEKON SYSTEM RESET & REBUILD"
echo "============================================"
echo ""

# Step 1: Stop all containers
echo "📍 Step 1: Stopping all containers..."
docker-compose down
echo "✅ Containers stopped"
echo ""

# Step 2: Remove volumes to clear databases
echo "📍 Step 2: Clearing database volumes..."
docker-compose down -v
echo "✅ Volumes removed (clean slate)"
echo ""

# Step 3: Rebuild all images
echo "📍 Step 3: Rebuilding Docker images..."
docker-compose build --no-cache
echo "✅ Images rebuilt"
echo ""

# Step 4: Start all services
echo "📍 Step 4: Starting services..."
docker-compose up -d
echo "✅ Services started"
echo ""

# Step 5: Wait for Umay setup
echo "📍 Step 5: Waiting for Umay backend to be ready..."
sleep 5
for i in {1..30}; do
    if curl -s http://localhost:1923/api/v1/setup/status > /dev/null 2>&1; then
        echo "✅ Umay backend is ready"
        break
    fi
    echo "   Checking... ($i/30)"
    sleep 2
done

echo ""
echo "============================================"
echo "✨ RESET COMPLETE"
echo "============================================"
echo ""
echo "📚 Access URLs:"
echo "   - Umay Frontend: http://localhost:1881"
echo "   - Umay API Docs: http://localhost:1923/docs"
echo "   - Ötüken Frontend: http://localhost:5174"
echo "   - Ötüken API Docs: http://localhost:8080/docs"
echo ""
echo "👤 Default Admin Credentials:"
echo "   - Email: admin@umay.local"
echo "   - Password: Admin2026!"
echo ""
echo "🔑 Expected Groups After Setup:"
echo "   - Arazi (ARAZI) — Created automatically for Ötüken integration"
echo "   - Other groups — Create manually in Umay UI after login"
echo ""
