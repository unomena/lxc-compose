#!/bin/bash
# Redis Test - Basic operations from host
# Tests key-value operations, lists, and cleanup

echo "=== Redis Test ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Get container IP
CONTAINER_IP=$(lxc list redis-ubuntu-24-04 -f json | jq -r '.[0].state.network.eth0.addresses[] | select(.family=="inet").address')

if [ -z "$CONTAINER_IP" ]; then
    echo -e "${RED}✗${NC} Could not determine container IP"
    exit 1
fi

echo "Redis IP: $CONTAINER_IP"

# Test using lxc exec to run redis-ubuntu-24-04-cli commands
echo ""
echo "1. Setting a key-value pair..."
lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli SET test_key "test_value"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Key set"
else
    echo -e "${RED}✗${NC} Failed to set key"
    exit 1
fi

echo ""
echo "2. Getting the value..."
RESULT=$(lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli GET test_key | tr -d '\r\n')
if [ "$RESULT" = "test_value" ]; then
    echo -e "${GREEN}✓${NC} Value retrieved: $RESULT"
else
    echo -e "${RED}✗${NC} Failed to get correct value (got: $RESULT)"
    exit 1
fi

echo ""
echo "3. Creating a list..."
lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli RPUSH test_list "item1" "item2" "item3" > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} List created"
else
    echo -e "${RED}✗${NC} Failed to create list"
    exit 1
fi

echo ""
echo "4. Getting list length..."
LENGTH=$(lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli LLEN test_list | tr -d '\r\n')
if [ "$LENGTH" = "3" ]; then
    echo -e "${GREEN}✓${NC} List length correct: $LENGTH"
else
    echo -e "${RED}✗${NC} Incorrect list length (got: $LENGTH)"
    exit 1
fi

echo ""
echo "5. Setting a hash..."
lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli HSET test_hash field1 "value1" field2 "value2" > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Hash created"
else
    echo -e "${RED}✗${NC} Failed to create hash"
    exit 1
fi

echo ""
echo "6. Getting hash field..."
HASH_VALUE=$(lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli HGET test_hash field1 | tr -d '\r\n')
if [ "$HASH_VALUE" = "value1" ]; then
    echo -e "${GREEN}✓${NC} Hash field retrieved: $HASH_VALUE"
else
    echo -e "${RED}✗${NC} Failed to get hash field (got: $HASH_VALUE)"
    exit 1
fi

echo ""
echo "7. Setting key with expiration..."
lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli SETEX test_expire 2 "will_expire" > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Expiring key set"
    echo "  Waiting 3 seconds for expiration..."
    sleep 3
    EXPIRED=$(lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli GET test_expire | tr -d '\r\n')
    if [ "$EXPIRED" = "" ] || [ "$EXPIRED" = "(nil)" ]; then
        echo -e "${GREEN}✓${NC} Key expired correctly"
    else
        echo -e "${RED}✗${NC} Key did not expire (got: $EXPIRED)"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Failed to set expiring key"
    exit 1
fi

echo ""
echo "8. Deleting test keys..."
lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli DEL test_key test_list test_hash > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Keys deleted"
else
    echo -e "${RED}✗${NC} Failed to delete keys"
    exit 1
fi

echo ""
echo "9. Verifying cleanup..."
EXISTS=$(lxc exec redis-ubuntu-24-04 -- redis-ubuntu-24-04-cli EXISTS test_key test_list test_hash | tr -d '\r\n')
if [ "$EXISTS" = "0" ]; then
    echo -e "${GREEN}✓${NC} All test keys removed"
else
    echo -e "${RED}✗${NC} Some keys still exist"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All Redis tests passed!${NC}"
exit 0