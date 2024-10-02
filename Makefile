build:
	sudo rm flist
	sudo flist uninstall
	v -o flist .
	sudo ./flist install