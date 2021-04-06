import pandas as pd
import copy as cp
import os

df = pd.read_csv(
    r"d:\Sync_ColorCloud\LogAnalysis\TopLogAnalysis - Copy\Data\GeneralLogs\20020507.txt",
    sep="\t",
    encoding="utf_16_le",
    usecols=["sCode", "dateTime", "sDescription"])

df2 = cp.deepcopy(df)
df.index = df.index + 1
df = pd.merge(df, df2, left_index=True, right_index=True)
df["Code_ES"] = df["sCode_x"] + " " + df["sDescription_y"]
df["ES_Flag"] = "N"
total_lines = df.shape[0]
i = 0
es_str1 = "abc"
while i < total_lines:
    step = 0
    j = 0
    a = df.iloc[i, 5]
    if df.iloc[i, 5] == "Analyzer Status changed from Busy to Emergency stop.":
        #os.system("pause")
        es_str1 = "abc"
        es_str2 = "abc"
        if es_str1 != "Analyzer Status changed from Busy to Emergency stop.":
            df.iloc[i, 7] = "Y"
            es_str1 = "Analyzer Status changed from Busy to Emergency stop."
        j = 1
        while (i + j <= total_lines) and (pd.to_datetime(df.iloc[i + j, 1]) - pd.to_datetime(df.iloc[i, 1])) / pd.Timedelta(1, "S") < 3600:
            if (df.iloc[i + j, 5] == "Analyzer Status changed from Busy to Emergency stop.") and (df.iloc[i + j, 0] != df.iloc[i, 0]):
                df.iloc[i + j, 7] = "Y"
                if es_str2 != "Analyzer Status changed from Busy to Emergency stop.":
                    step = j
                    es_str2 = "Analyzer Status changed from Busy to Emergency stop."
            j = j + 1
    if step > 0:
        i = i + step + 1
    elif j > 1:
        i = i + j
    else:
        i = i + 1

df.to_csv("d:\\es.csv", index_label="index")

