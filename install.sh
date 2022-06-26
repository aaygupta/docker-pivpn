VERSION="1.0"
config="1"
seed="1"
extra=""

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -c|--config)
    config="$2"
    shift # past argument
    shift # past value
    ;;
    -r|--rand)
    seed="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    help=YES
    shift # past argument
    ;;
    -b|--build)
    build=YES
    shift # past argument
    ;;
    -d|--dev)
    dev=YES
    shift # past argument
    ;;
    -n|--nopass)
    extra="nopass"
    shift # past argument
    ;;
esac
done

display_help() {
    echo
    echo "Script version $VERSION"
    echo 'A tool for setting up a docker container with PiVPN'
    echo 'Usage: setup.sh <options>'
    echo 'Options:'
    echo '   -h --help                   Show help'
    echo '   -b --build                  Builds dockerfile'
    echo '   -c --config <amount>        Specify the amount of client configs you want'
    echo '   -r --rand <amount>          Specify the amount of random data (in 100s of bytes) that you want your Docker container to be seeded with'
    echo '   -d --dev                    Runs in developer mode'
    echo '   -n --nopass                 Creates a .ovpn file with no password'
    exit 1
}

build_setup() {
    docker build -t docker-pivpn:1.0 .
    container="$(docker run -i -d -P --cap-add=NET_ADMIN docker-pivpn:1.0)" # check if permissons can be lowered
}

detect_port() {
    output=$(docker port "$container" 1194/udp)
    port=${output#0.0.0.0:}
    echo Your port is $port
}

pivpn_setup() {
    # ssh root@127.0.0.1 -i "$HOME/.ssh/id_rsa" -p $port
    echo "$container"
    seed_random
    docker exec -it $container bash install.sh
    docker exec -it $container dpkg --configure -a
    docker exec -it $container bash install.sh
    echo "Restarting container . . ."
    docker restart $container
    detect_port
    docker exec -it $container sed -i 's/1194/'"$port"'/g' /etc/openvpn/easy-rsa/pki/Default.txt
    gen_config
    echo "Done! To execute commands, type docker exec -it $container /bin/bash"
    echo "All currently generated configs are in the ovpns directory"
    echo "To generate more configs, just type docker exec -it $container pivpn -a"
    echo "Your openvpn port should be $port, open it up if you are using a firewall"
}

gen_config() {
    count=0
    while [[ $count -lt $config ]]; do
        echo "Generating configs . . . Please answer the prompts"
        docker exec -it $container pivpn -a $extra
        count+=1
    done

    docker cp $container:/home/pivpn/ovpns ovpns
}

seed_random() {
    # Moving script
    if [ -e randwrite.sh ]; then
        docker cp randwrite.sh $container:/randwrite.sh
    else
        docker cp docker-pivpn/randwrite.sh $container:/randwrite.sh
    fi

    # Writing random data
    count=0
    while [[ $count -lt $seed ]]; do
        rand="$(head -100 /dev/urandom)"
        docker exec $container bash randwrite.sh "$rand"
        count+=1
    done
}

# Help option
if [ "$help" == YES ]; then
    display_help
fi

platform=$(python -c "import platform; print(platform.dist()[0])")

build_setup