setwd("/n/ngs/runs/log")

#install.packages("lubridate",repos="http://cran.us.r-project.org")

library(lubridate)
library(yaml)

logfiles<-system("ls -tr *.log",intern=T)
fcids<-gsub(".log","",logfiles)



logfile<-list()
data<-list()
totaltimes<-vector()

pdf("dotcharts.pdf",height=8,width=16)
for(i in 1:length(logfiles))
{
	logfile[[i]]<-read.table(logfiles[i],sep='\t',as.is=T)

	flowcell_dir<-system(paste("find /n/ngs/data -maxdepth 1 -type d -name \"*",fcids[i],"\"",sep=''),intern=T)
	if(file.exists(paste(flowcell_dir,"/flowcell_info.yaml",sep='')))
	{
		flowcell_file<-paste(flowcell_dir,"/flowcell_info.yaml",sep='')
		flowcell_info<-yaml.load_file(flowcell_file)

		prot<-flowcell_info[[2]][[1]]$`:protocol`

		seen_genomes<-vector()

		for(j in 1:length(flowcell_info[[2]]))
		{
			cur_genome<-flowcell_info[[2]][[j]]$`:genome`
			if(length(grep(cur_genome,seen_genomes))>0)
			{
			}else
			{
				seen_genomes<-c(seen_genomes,cur_genome)
			}
		}

		flowcell_info[[2]][[1]]$`:genome`
	}else
	{
		seen_genomes<-NA
		prot<-NA
	}

	#gave up on rjson and RJSONIO because no quotes...
	temp<-gsub("[\\{\\}]","",logfile[[i]][,1])

	temp<-matrix(unlist(sapply(temp,strsplit,",message:")),ncol=2,byrow=T)
	temp<-data.frame(temp,ymd_hms(temp[,1]))
	data[[i]]<-temp

	firsttime<-temp[1,3]
	reltimes<-difftime(temp[,3],temp[1,3],units="hours")

	totaltime=round(max(reltimes))
	totaltimes[i]<-totaltime

	par(mar=c(5,9,3,1),oma=c(1,0,1,1))
	dotchart(rev(as.matrix(reltimes)),labels=rev(temp[,2]),groups=factor(rep("",times=length(reltimes))),main=paste(fcids[i],paste(seen_genomes,collapse=","),prot),xlab=paste("Hours (total duration:",totaltime,")",sep=''))
}
dev.off()

#when I started
mcm.iv<-which(logfiles=="BC27LUACXXA.log"):length(logfiles)
par(mar=c(10,3,3,1))
cols<-rep("gray",times=length(logfiles))
cols[mcm.iv]<-'blue'
barplot(totaltimes,names.arg=logfiles,las=2,cex.names=.8,col=cols)

for(i in 1:length(data))
{
	startpos<-min(grep("starting",data[[i]][,2]))
	endpos<-min(grep("postrun done",data[[i]][,2]))

	if(is.finite(startpos) & is.finite(endpos))
	{
		dur<-difftime(data[[i]][endpos,3],data[[i]][startpos,3],units="hours")
		cat(i,dur,"\n")
	}
}
