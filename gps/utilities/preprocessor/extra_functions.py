# decimal to binary converter
# Call d2b(x) to convert x from decimal to binary
# x must be a nonnegative integer
#d2b = lambda n: n>0 and d2b(n>>1).lstrip('0')+str(n&1) or '0'

def d2b(n, width=0):
    x = n > 0 and d2b(n>>1).lstrip('0')+str(n&1) or '0'
    if width > 0:
        x.rjust(width,'0')
    return x

# print wire function
# 
