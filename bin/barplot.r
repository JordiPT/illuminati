library(ggplot2)
library(scales)
library(plyr)

args = commandArgs(TRUE)
data = args[1]
filename = args[2]

input = read.table(data,sep=":")

jpeg(filename)

ggplot(input,aes(x=V2,y=V3,fill=V1,order=desc(V1))) +
geom_bar(stat="identity") +
scale_y_continuous(labels=comma) +
labs(x="Lane",y="Reads",title="FASTQ FILES SIZE") +
theme_bw()

dev.off()