# EX02 - Shared State

```
terraform init
terraform apply
scp *.py ec2-user@<public ip>:~/    #both nodes
```

`<a>`, `<b>`, `<store>` = private IPs from the terraform output, reset the store before every task 2 / 3 run:

```
redis6-cli set counter 0; redis6-cli set ready 0; redis6-cli del lock    #on the store
```

## 1.1

```
python3 replicated_max.py A 5000 <b>:5001 10    #on A
python3 replicated_max.py B 5001 <a>:5000 7     #on B
```

## 1.2

```
python3 replicated_max.py A 5000 <b>:5001 1 5
python3 replicated_max.py B 5001 <a>:5000 1 5
```

## 1.4

```
python3 replicated_gcounter.py A 5000 <b>:5001 10 9
python3 replicated_gcounter.py B 5001 <a>:5000 7 9
```

## 2.1

```
python3 single_copy.py A <store> incr 1000
python3 single_copy.py B <store> incr 1000
```

## 2.2

mode = unsafe / incr / lock / watch, last argument = hold between read and write in s

```
python3 single_copy.py A <store> <mode> 3 1
python3 single_copy.py B <store> <mode> 3 1
```

## 3.1

```
python3 bench_replicated.py A 5000 <b>:5001 100 5
python3 bench_replicated.py B 5001 <a>:5000 100 5

python3 single_copy.py A <store> <mode> 100    #alone, set ready 1 first
python3 single_copy.py B <store> <mode> 100    #concurrent, also run on B
```

```
terraform destroy
```
