#run only once
setup(){
	echo " "
	echo " ██████╗██╗      ██████╗ ██╗   ██╗██████╗ ███████╗██╗      █████╗ ██████╗ ███████╗"
	echo "██╔════╝██║     ██╔═══██╗██║   ██║██╔══██╗██╔════╝██║     ██╔══██╗██╔══██╗██╔════╝"
	echo "██║     ██║     ██║   ██║██║   ██║██║  ██║█████╗  ██║     ███████║██████╔╝█████╗  "
	echo "██║     ██║     ██║   ██║██║   ██║██║  ██║██╔══╝  ██║     ██╔══██║██╔══██╗██╔══╝  "
	echo "╚██████╗███████╗╚██████╔╝╚██████╔╝██████╔╝██║     ███████╗██║  ██║██║  ██║███████╗"
	echo " ╚═════╝╚══════╝ ╚═════╝  ╚═════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝"
	echo "                                                                                  "
	echo "██████╗ ██████╗ ███╗   ██╗███████╗                                                "
	echo "██╔══██╗██╔══██╗████╗  ██║██╔════╝                                                "
	echo "██║  ██║██║  ██║██╔██╗ ██║███████╗                                                "
	echo "██║  ██║██║  ██║██║╚██╗██║╚════██║                                                "
	echo "██████╔╝██████╔╝██║ ╚████║███████║                                                "
	echo "╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝                                                "
	echo " "
																					
	read -p 'Cloudflare API Token: ' CLOUDFLARE_API_TOKEN
	read -p 'Zone ID: ' ZONE_ID
	echo ""

	result=$(curl -sS https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records \
		-H "Authorization: Bearer $CLOUDFLARE_API_TOKEN")

	#if api token or zone-id is incorrect
	success=$(echo "$result" | jq '.success')
	if [[ "$success" == "false" ]]; then
		error_code=$(echo "$result" | jq '.errors.[0].code')
		if [[ "$error_code" == "7003" ]]; then
			echo "Wrong Zone ID"
			echo "$result" | jq '.errors.[0].message' | tr -d '"'
		fi
		if [[ "$error_code" == "10001" ]]; then
			echo "Wrong API Token"
			echo "$result" | jq '.errors.[0].message' | tr -d '"'
		fi
		exit 403
	fi

	COUNT_A_RECORD=$(echo "$result" | jq '.result | map(select(.type == "A")) | length')

	for i in $(seq 0 $((COUNT_A_RECORD-1)))
	do
		name=$(echo "$result" | jq '.result | map(select(.type == "A")) | .['"${i}"'].name' | tr -d '"')
		ip=$(echo "$result" | jq '.result | map(select(.type == "A")) | .['"${i}"'].content' | tr -d '"')
		echo "${i}: ${name} (${ip})"
	done

	#select one domain with dynamic IP
	echo ""
	read -p 'Domain ('"0 - $(($COUNT_A_RECORD-1))"'): ' SELECTION

	DOMAIN_RECORDS=$(echo "$result" | jq '.result | map(select(.type == "A")) | .['"${SELECTION}"']' \
	| jq 'del(.proxiable)' | jq 'del(.settings)' | jq 'del(.meta)' | jq 'del(.comment)' \
	| jq 'del(.tags)' | jq 'del(.created_on)' | jq 'del(.modified_on)' | jq 'del(.comment_modified_on)'
	)

	CREDENTIALS=$(echo "{}" | jq '.api_token |= .+"'"${CLOUDFLARE_API_TOKEN}"'"' \
	|   jq '.zone_id |= .+"'"${ZONE_ID}"'"'
	)

	#save domain details and credentials
	echo "{}" | jq '.records |= .+'"${DOMAIN_RECORDS}"'' | \
		jq '.credentials |= .+'"${CREDENTIALS}"'' > cloudflare-ddns.json
}

change_ip(){
	CLOUDFLARE_API_TOKEN=$(jq .credentials.api_token cloudflare-ddns.json | tr -d '"')
	ZONE_ID=$(jq .credentials.zone_id cloudflare-ddns.json | tr -d '"')
	DNS_RECORD_ID=$(jq .records.id cloudflare-ddns.json | tr -d '"')
	IP=$(curl -sS ipv4.icanhazip.com)

	echo ""
	curl https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$DNS_RECORD_ID \
	-X PATCH \
	-H 'Content-Type: application/json' \
		-H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
	-d '{
			"name": "'$(jq .records.name cloudflare-ddns.json | tr -d '"')'",
			"ttl": '"$(jq .records.ttl cloudflare-ddns.json)"',
			"type": "'$(jq .records.type cloudflare-ddns.json | tr -d '"')'",
			"comment": "DDNS Change",
			"content": "'"$IP"'",
			"proxied": '"$(jq .records.proxied cloudflare-ddns.json)"'
		}'
	
	# keep changed IP in json file
	ip_change=$(jq '.records.content = "'"$IP"'"' cloudflare-ddns.json)
	#write to log
	echo "$(jq .records.content cloudflare-ddns.json | tr -d '"') > ${IP} - $(date)" > cloudflare-ddns.log
	echo ${ip_change} | jq '.' > cloudflare-ddns.json
	echo -e "\n"
}

main(){
	# if no setup done before
	if [ ! -f ./cloudflare-ddns.json ]; then
		setup
		change_ip
        echo -e '\e[4mAdd the following statement to your crontab:\e[24m'
		echo -e "*/5 * * * * $(pwd)/cloudflare-ddns.sh >/dev/null 2>&1\n"

	else
		#if IP address changed
		if [[ $(curl -sS ipv4.icanhazip.com) != $(jq .records.content cloudflare-ddns.json | tr -d '"') ]]; then
			echo "Dynamic IP Changed"
			change_ip
		fi
	fi
}

main "$@"




