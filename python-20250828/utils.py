

def mean_sd(df):
  mean = round(df.mean())
  sd = round(df.std())
  return f'{mean:,} +/- {sd:,}'

def dollar(x):
  mx = round(x)
  return f'${mx:,}'

def pcntdf(df):
  return pcnt(df.mean())

def pcnt(x):
  if x>0.1:
    mx = round(100*x)
  elif x>0.01:
    mx = round(1000*x)/10
  else:
    mx = round(10000*x)/100

  return f'{mx:,}%'


# https://hplgit.github.io/prog4comp/doc/pub/._p4c-bootstrap-Python028.html
def secant(f, x0, x1, eps):
    f_x0 = f(x0)
    #print("trying insurance", x0, f_x0)
    f_x1 = f(x1)
    #print("trying insurance", x1, f_x1)
    iteration_counter = 0
    x = x0
    while abs(f_x1) > eps and iteration_counter < 15:

        denominator = float(f_x1 - f_x0)/(x1 - x0)
        x = x1 - float(f_x1)/denominator

        x0 = x1
        x1 = x
        f_x0 = f_x1
        f_x1 = f(x1)
        #print("trying insurance", x1, f_x1)
        iteration_counter += 1
    # Here, either a solution is found, or too many iterations
    if abs(f_x1) > eps:
          raise ValueError("No solution found")
    return x
