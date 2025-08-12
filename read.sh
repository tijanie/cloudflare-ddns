#apt install dialog
#apt install newt

for i in $(seq 0 $((COUNT_A_RECORD-1)))
do
    name=$(echo "$result" | jq '.result | map(select(.type == "A")) | .['"${i}"'].name' | tr -d '"')
    ip=$(echo "$result" | jq '.result | map(select(.type == "A")) | .['"${i}"'].content' | tr -d '"')
    echo "${i}: ${name} (${ip})"
done

whiptail --title "Check list example" --checklist \
"Choose user's permissions" 20 78 4 \
"NET_OUTBOUND" "Allow connections to other hosts" ON \
"NET_INBOUND" "Allow connections from other hosts" OFF \
"LOCAL_MOUNT" "Allow mounting of local devices" OFF \
"REMOTE_MOUNT" "Allow mounting of remote devices" OFF

# Dialog box size 20 78 4
DOMAIN = $(whiptail --title "Choose Domains" --checklist \
"Choose the Dynamic Domains" 20 78 4 \
"${name[@]} - ${ip[@]}" OFF)

