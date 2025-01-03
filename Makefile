os-update: 
	dnf -y install dnf-utils
	echo "fastestmirror=1" >> /etc/dnf/dnf.conf
	dnf -y update && reboot

setup:
	dnf -y install perf cargo strace bcc-tools wireshark ripgrep

clean:
        rm -rf curl-output.txt perf.data perf.data.old sslkeylog.txt tcpdump.pcap vmlinux insn-trace call-trace

run: perf.data/kcore_dir/kcore

perf.data/kcore_dir/kcore:
        export SSLKEYLOGFILE=$(PWD)/sslkeylog.txt
        resolvectl flush-caches && echo 3 > /proc/sys/vm/drop_caches && sync
        sleep 3
        tcpdump -i wlo1 -w /tcpdump.pcap &
        perf record --kcore -e intel_pt/cyc,noretcomp=1/ curl -vvvkLo /dev/null https://google.com 2> curl-output.txt
        sleep 1
        pkill tcpdump

vmlinux: perf.data/kcore_dir/kcore
        cp /usr/lib/debug/lib/modules/$(shell uname -r)/vmlinux .
        dd if=perf.data/kcore_dir/kcore of=vmlinux bs=4096 skip=1 seek=512 count=5120 conv=nocreat,notrunc

call-trace: vmlinux
        perf script --xed --vmlinux=./vmlinux --call-trace > call-trace

insn-trace: vmlinux
        perf script --xed --vmlinux=./vmlinux --insn-trace -F+srcline,+srccode > insn-trace

.PHONY: clean run os-update setup
