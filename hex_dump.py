import sys

s = b"/bin//sh"
print(s)
for val in s:
    print("\\x%02x" % (val), end="")

