up:
	sudo ln -s $(PWD)/mountsda.service /etc/systemd/system/mountsda.service
	sudo systemctl enable mountsda
down:
	sudo systemctl disable mountsda
start:
	sudo systemctl start mountsda
stop:
	sudo systemctl stop mountsda
log:
	systemctl -l status mountsda.service
tail:
	journalctl -u -b -f mountsda
