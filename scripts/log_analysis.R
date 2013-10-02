setwd("/n/ngs/runs/log")

#install.packages("lubridate",repos="http://cran.us.r-project.org")

logfiles<-system("ls -tr *.log",intern=T)

logfile<-list()
data<-list()
totaltimes<-vector()

pdf("dotcharts.pdf",height=8,width=16)
for(i in 1:length(logfiles))
{
	logfile[[i]]<-read.table(logfiles[i],sep='\t',as.is=T)

	#gave up on rjson and RJSONIO because no quotes...
	temp<-gsub("[\\{\\}]","",logfile[[i]][,1])

	temp<-matrix(unlist(sapply(temp,strsplit,",message:")),ncol=2,byrow=T)
	temp<-data.frame(temp,ymd_hms(temp[,1]))
	data[[i]]<-temp

	firsttime<-temp[1,3]
	reltimes<-(temp[,3]-temp[1,3])/3600 #hours

	totaltime=round(max(reltimes))
	totaltimes[i]<-totaltime

	par(mar=c(5,9,3,1),oma=c(1,0,1,1))
	dotchart(rev(as.matrix(reltimes)),labels=rev(temp[,2]),groups=factor(rep("",times=length(reltimes))),main=logfiles[i],xlab=paste("Hours (total duration:",totaltime,")",sep=''))
}
dev.off()

#when I started
mcm.iv<-which(logfiles=="BC27LUACXXA.log"):length(logfiles)
par(mar=c(10,3,3,1))
cols<-rep("gray",times=length(logfiles))
cols[mcm.iv]<-'blue'
barplot(totaltimes,names.arg=logfiles,las=2,cex.names=.8,col=cols)
