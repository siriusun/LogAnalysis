#将文本导入pandas, 生成单列文本Series;然后根据连续多行特征（正则匹配）要求筛选文本，不符合的内容将被筛选掉。
import re
import os
import pandas as pd
import datetime

start = datetime.datetime.now()
work_path = os.path.split(os.path.abspath(__file__))[0]

df = pd.read_csv(
    r"c:\Users\sirius\Desktop\百色\19010357_03-31-2021_13-36-24\02-2021-traces\one_trace.csv",
    encoding="utf_8",
    index_col="index")


#data_frame:2 col, index and content; filter_regex_list: 1-n line regex list.
def super_filter(data_frame, filter_regex_list):
    data_frame.reset_index(drop=True, inplace=True)
    data_frame["flag"] = "N"
    total_lines = data_frame.shape[0]
    total_regex = len(filter_regex_list)
    for i in range(total_lines):
        if re.search(filter_regex_list[0], data_frame.iloc[i, 0]) == None:
            continue
        flag = False
        for j in range(1, total_regex):
            if re.search(filter_regex_list[j], data_frame.iloc[i + j,
                                                               0]) == None:
                break
            flag = True
        if flag == True:
            for j in range(total_regex):
                data_frame.iloc[i + j, 1] = "Y"
    data_frame = data_frame[data_frame.flag == "Y"]
    data_frame.drop("flag", axis=1, inplace=True)
    data_frame.reset_index(drop=True, inplace=True)
    return data_frame


#连续匹配行正则模板列表
df = super_filter(df, ["Start Arm\|LLD est\. ms\|", "\|EH\|.*\|1419\|"])
df.to_csv(work_path + "\\done.csv", index_label="index")

print(datetime.datetime.now() - start)
