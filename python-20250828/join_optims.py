import pandas as pd

df = pd.read_csv('optim_out_run0.csv')
df = df.rename(columns=lambda x: x.strip())
#print(df)
for file in ['optim_out_run1.csv', 
             'optim_out_run2.csv',
             'optim_out_run3.csv',
             'optim_out_run4.csv',
             'optim_out_run5.csv',
             'optim_out_run6.csv',
             'optim_out_run7.csv',
             'optim_out_run8.csv',
             'optim_out_run9.csv',
             'optim_out_run10.csv',
             'optim_out_run11.csv']:
  df1 = pd.read_csv(file)
  df1 = df1.rename(columns=lambda x: x.strip())
  df1 = df1.reset_index()  # make sure indexes pair with number of rows
  #print(df1['annual_income'])
  for index, row in df1.iterrows():    
   
    other_ix = (df['loan_duration']==row['loan_duration']) & \
                (df['annuity_duration']==row['annuity_duration']) & \
                (df['loan_type']==row['loan_type'])
    if len(df[other_ix]) == 1: 
      other_inc = df['annual_income'][other_ix].iloc[0]
      #print("comparing", row['loan_duration'], row['annuity_duration'], row['loan_type'], row['annual_income'], other_inc, row['pcnt_hol'])
      if row['annual_income'] > other_inc and row['pcnt_hol'] < 26.0: 
        for key in [ 'annual_income',
                      'total_income', 'roi', 'pcnt_hol', 'insurance_pa', 'holiday_enter',
                      'holiday_exit', 'repay_amount_factor', 'repay_start_factor',
                      'funder_profit_share', 'surplus', 'interest_deficit', 'funder_earned',
                      'cum_interest_paid']:
          df.loc[other_ix,key] =  row[key]
   
df.to_csv('joined_optims.csv', index=False)