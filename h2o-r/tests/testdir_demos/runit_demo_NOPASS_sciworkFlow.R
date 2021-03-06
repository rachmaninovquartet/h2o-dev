#Split data into test/train.
#Do Grid search over lambda and Score all the models on a test set. Choose the best model by auc on the test set.
#Do grid search on gbm and predict on test set. Print the aucs and model params "

setwd(normalizePath(dirname(R.utils::commandArgs(asValues=TRUE)$"f")))
source('../h2o-runit.R')


test <- function(conn) {
print("Reading in prostate dataset")
pros.hex <- h2o.importFile(conn,normalizePath(locate("smalldata/logreg/prostate.csv")), key="pros.hex")
print ("Run summary")
summary(pros.hex)
print("Summary of a column")
print(summary(pros.hex$CAPSULE))
print("Convert a column to factor")
pros.hex$CAPSULE <- as.factor(pros.hex$CAPSULE)
print("print the summary again")
print(summary(pros.hex$CAPSULE))
print("Print quantile of a column")
print(quantile(pros.hex$AGE,probs=seq(0,1,.1)))

print("split frame into test train")
 a <- h2o.splitFrame(pros.hex,ratios=c(.2),shuffle=T)
print("print dimension and assign to test and train")
print(dim(a[[1]]))
print(dim(a[[2]]))
pros.train <- a[[2]]
pros.test <- a[[1]]

myX <- c("AGE","RACE","DPROS","DCAPS","PSA","VOL","GLEASON")
myY <- "CAPSULE"

#GLM
print("Build GLM model")   
my.glm <- h2o.glm(x=myX, y=myY, data=pros.train, family="binomial",standardize=T,use_all_factor_levels=TRUE,higher_accuracy=T,lambda_search=T,return_all_lambda=T,variable_importances=FALSE)
print(my.glm)

print("This is the best model")
best_model <- my.glm@best_model
print(best_model)

print("predict on best lambda model")
pred <- predict(my.glm@models[[best_model]],pros.test)
print(head(pred))

print("print performance and auc")
perf <- h2o.performance(pred$'1',pros.test$CAPSULE )
print(perf)
print(perf@model$auc)
plot(perf,type="roc")

result_frame <- data.frame(id = 0,auc = 0 , key = 0)

print("print performance for all models on test set")
for(i in 1:100){
  pred <- predict(my.glm@models[[i]],pros.test)
  perf <- h2o.performance(pred$'1',pros.test$CAPSULE )
  print ( paste ("  model number:", i, "  auc on test set: ", round(perf@model$auc, digits=4),  sep=''), quote=F)
  result_frame <- rbind(result_frame, c(i,round(perf@model$auc, digits=4),my.glm@models[[i]]@key))
}

result_frame <- result_frame[-1,]
result_frame
print("order the results by auc on test set")
ordered_results <- result_frame[order(result_frame$auc,decreasing=T),]
ordered_results
print("get the model that gives the best prediction using the auc score")
glm_best_model <- h2o.getModel(conn,key = ordered_results[1,"key"])
print(glm_best_model)

#GBM
print("Grid search gbm")
pros.gbm <- h2o.gbm(x = myX, y = myY, distribution = "bernoulli", data = pros.train, n.trees = c(50,100),n.minobsinnode=1, 
                    interaction.depth = c(2,3), shrinkage = c(0.01,.001), n.bins = c(20), importance = F) 
pros.rf <- h2o.randomForest(x=myX,y=myY,data=pros.train,classification=T,ntree=c(5,10),depth=10,mtries=c(2,5),importance=F, type = "BigData")
print(pros.gbm)
pros.gbm@sumtable
print("number of models built")
num_models <- length(pros.gbm@sumtable) 
print(num_models)

print("Scoring")
for ( i in 1:num_models ) {
  #i=1
  model <- pros.gbm@model[[i]]
  pred <- predict( model, pros.test )
  perf <- h2o.performance ( pred$'1', pros.test$CAPSULE, measure="F1" )
  
  print ( paste ( pros.gbm@sumtable[[i]]$model_key, " trees:", pros.gbm@sumtable[[i]]$n.trees,
                  " depth:", pros.gbm@sumtable[[i]]$interaction.depth,
                  " shrinkage:", pros.gbm@sumtable[[i]]$shrinkage,
                  " min row: ", pros.gbm@sumtable[[i]]$n.minobsinnode, 
                  " bins:", pros.gbm@sumtable[[i]]$nbins,
                  " auc:", round(perf@model$auc, digits=4), sep=''), quote=F)
}

print(" Performance measure on a test set ")
model <- pros.gbm@model[[1]] #  my.glm@models[[80]], pros.rf@model[[1]] 
pred <- predict ( model, pros.test )
perf <- h2o.performance ( pred$'1', pros.test$CAPSULE, measure="F1" )
print(perf)

testEnd()
}

doTest("Split data into test/train, do Grid search over lambda and Score all the models on a test set and choose the best model by auc on the test set. Do grid search on gbm and predict on test set, print the aucs and model params ", test)
