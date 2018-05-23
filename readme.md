tasks through a chain of ssh-able network hosts

# chain of hosts
the chain starts from local machine by default (local can be missed in the chain specifying). for each host in the chain, it can ssh the next machine, but the reverse ssh or ssh to further machine may not work.

for example: user1@host1, user2@host2
we can ssh user1@host1 in local or ssh user2@host2 in host1
but the reverse, like ssh user1@host1 in host2, or ssh to further host, like ssh user2@host2 in local, might fail

# tasks
## scp-chain
transfer files/directories through the chain

### furthur progress
1. remove legacy in the middle of chain

## ssh-chain
execute commands in the end host of chain

## ssh commands parser

**work not started**

parse a serial of bash/ssh/scp commands inputed in terminal to a string used in bash command

for example, commands as following:
``scp file1 user1@host1:~
ssh user1@host1
scp ~/file1 user2@host2:~
exit``
should be parsed to the following string:
    ``scp file1 user1@host1:~; ssh user1@host1 "scp ~/file1 user2@host2:~"``
which can be executed in bash