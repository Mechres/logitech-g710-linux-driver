
KVERSION = $(shell uname -r)
KDIR := /lib/modules/$(KVERSION)/build
PWD := $(shell pwd)

# Check if the kernel was built with Clang/LLVM
ifeq ($(shell grep -q "CONFIG_CC_IS_CLANG=y" $(KDIR)/.config 2>/dev/null && echo "yes"),yes)
    LLVM_OPT := LLVM=1
endif

obj-m = hid-lg-g710-plus.o

default: build

build:
	make -C $(KDIR) M=$(PWD) $(LLVM_OPT) modules
clean:
	make -C $(KDIR) M=$(PWD) $(LLVM_OPT) clean
install:
	make -C $(KDIR) M=$(PWD) $(LLVM_OPT) modules_install