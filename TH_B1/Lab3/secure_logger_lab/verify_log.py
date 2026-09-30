import hashlib

lines = open("secure.log", encoding="utf-8").read().splitlines()
sigs = open("secure.log.sig", encoding="utf-8").read().split()[-len(lines):]
for i, (line, sig) in enumerate(zip(lines, sigs), 1):
    ok = hashlib.sha256(line.encode("utf-8")).hexdigest() == sig
    print(i, "OK" if ok else "DA BI SUA")
