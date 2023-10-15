import pandas as pd
import ast
import re
import os
import datetime as dt

def clean_param(param):
    after_clean = re.sub(r"\d,22\sserialization::archive\s9\s\d\s", "", param)
    after_clean = re.sub(r"\\", "/", after_clean)
    if re.search(r"\d{1,2}\s",after_clean) == None:
        return after_clean
    else :
        return re.sub(r"\d{1,2}\s", "", after_clean)
    
def param_to_list(param):
    return ast.literal_eval("[" + param + "]")
    
def to_hex(df):
    if df.hexLocation != -1:
        hex_index = int(df.hexLocation)
        df.Parameters[hex_index] = str(hex(int(df.Parameters[hex_index])))
    return df

def file_filter(filedir, keyword):
    allfilelist = os.listdir(filedir)
    targetfiles = [file for file in allfilelist if keyword in file]
    return targetfiles

def strlist(slist):
    return "||".join(slist)

code_type = {
    "69": "Error",
    "73": "Info",
    "87": "Warning"
    }

work_path = os.path.split(os.path.abspath(__file__))[0]
print(work_path)
bf_logs = file_filter((work_path + "\\InstrumentLog"), ".txt")

dferror = pd.read_excel((work_path + "\\BF_error_class.xlsx"), sheet_name="ErrorList")

bf_log_list = []
log_count = len(bf_logs)
selected_columns = ["Type", "DateTime", "ResourceId", "Parameters"]

os.system("pause")

dt_start = dt.datetime.now()

print("*"*50)
for bf_log in bf_logs:
    print(f"{log_count}: Start to import: {bf_log}")
    df= pd.read_csv((work_path + "\\InstrumentLog\\" + bf_log), sep="\t", usecols=selected_columns)
    df = df.loc[df.Type.isin(["87", "69"])]
    bfsn = bf_log.split("_")[1]
    df["SN"] = bfsn
    df["DateTime"] = pd.to_datetime(df.DateTime + 28800, unit="s")
    df = pd.merge(df, dferror, how="left", left_on="ResourceId", right_on="errorID")
    print(df.info())
    df.dropna(subset={"errorID"}, axis=0, inplace=True)
    df.Parameters.fillna("", inplace=True)
    df["Parameters"] = df.Parameters.map(clean_param)
    df["Parameters"] = df.Parameters.map(param_to_list)
    df.hexLocation.fillna(-1,inplace=True)
    df = df.apply(to_hex, axis=1)
    bf_log_list.append(df)
    log_count -= 1
    print("*"*50)

dfall= pd.concat(bf_log_list)

dfall["Parameters"] = dfall.Parameters.map(strlist)

dfall["Type"] = dfall.Type.map(code_type)

month_series = dfall.DateTime.dt.strftime("%y%m")
month_series = month_series.drop_duplicates()

month_series.to_csv(work_path + "/InstrumentLog/monthIndex.csv")
dfall.to_csv(work_path + "/InstrumentLog/one.csv")

print(dt.datetime.now() - dt_start)

os.system("pause")