import re
import sys

EXPECTED_A = ("app-id=com.example.proof;pn-type=apple;"
              "pn-tok=" + "0" * 63 + "1:remote&" + "1" * 64 + ":voip;"
              "pn-silent=1;pn-timeout=0;pn-channel=calls")
EXPECTED_B = ("app-id=com.example.proof;pn-type=apple;"
              "pn-tok=" + "2" * 64 + ":remote&" + "3" * 64 + ":voip;"
              "pn-silent=1;pn-timeout=0;pn-channel=calls")


def main():
    text = open(sys.argv[1], newline="").read()
    requests = re.findall(r"^REGISTER .*?\r\n\r\n", text, re.S | re.M)
    contacts = [re.search(r"^Contact: (.*)$", r, re.M).group(1).strip() for r in requests]
    print("REGISTER requests seen: %d" % len(requests))
    ok = True
    for i, c in enumerate(contacts, 1):
        m = re.match(r"<sip:alice@[0-9.]+:\d+(?:;transport=\w+)?;(.*)>;expires=(\d+)$", c)
        if not m:
            print("  [%d] UNEXPECTED Contact shape: %s" % (i, c))
            ok = False
            continue
        params, expires = m.group(1), m.group(2)
        which = "A" if params == EXPECTED_A else "B" if params == EXPECTED_B else "?"
        print("  [%d] expires=%s token-set=%s" % (i, expires, which))
        if which == "?":
            ok = False
    expected_sets = (sys.argv[2] if len(sys.argv) > 2 else "A,A,B,B,B0").split(",")
    got = []
    for c in contacts:
        m = re.match(r"<sip:alice@[0-9.]+:\d+(?:;transport=\w+)?;(.*)>;expires=(\d+)$", c)
        if m:
            tag = "A" if m.group(1) == EXPECTED_A else "B" if m.group(1) == EXPECTED_B else "?"
            got.append(tag + ("0" if m.group(2) == "0" else ""))
    if got != expected_sets:
        print("FAIL: expected token-set sequence %s, got %s" % (expected_sets, got))
        ok = False
    if contacts and not contacts[-1].endswith(";expires=0"):
        print("FAIL: last REGISTER should be the unregister (expires=0)")
        ok = False
    print("RESULT: %s" % ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
