FROM debian:stable-slim
RUN apt update; apt install -y iproute2 net-tools traceroute dnsutils curl tcpdump iputils-ping nmap iptables netcat-traditional wget gawk tcpdump mount
CMD ["tail", "-f", "/dev/null"]