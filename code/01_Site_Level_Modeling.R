# =============================================================================
# Phase 1 — Site-level modelling
#
# Trains one classifier per groundwater monitoring station (Naive Bayes, SVM,
# CART, C5.0, Random Forest, XGBoost) under 10-fold cross-validation to predict
# monthly drought / non-drought, and records per-site AUC-ROC, AUC-PR.
# The per-site AUC-ROC is used to stratify stations into response subsets 
# (AUC-ROC threshold = 0.80).
#
# =============================================================================

# load required library

# manipulation 
library(dplyr)
library(tidyr)
library(tsibble)
library(slider)
library(reshape2)
library(DataExplorer)

# visualization
library(ggplot2)
library(ggpubr)

# modeling
library(forecast)
library(e1071)          # naiveBayes(), svm()
library(xgboost)
library(caret)
library(rpart)          # CART
library(rpart.plot)
library(randomForest)
library(C50)            # C5.0 decision tree
library(vip)
library(ranger)
library(glmnet)

# performance evaluation
library(performanceEstimation) # smote function is here
library(splitstackshape)
library(ROCR)

# import required data set
precipitation <- read.csv("complete_monthly_precipitation.csv") %>% as_tibble()
temperature <- read.csv("complete_monthly_temperature.csv") %>% as_tibble()
sgi.data <- read.csv("complete_monthly_SGI.csv") %>% as_tibble()
station.data <- read.csv("station_guide.csv")

# store stations ids in single data frame
station.ids <- station.data$code

# create data frames to store results (columns are built from the loop output;
# this also initialises error.results, which was previously missing)
auc.results   <- data.frame()
prc.results   <- data.frame()
error.results <- data.frame()

#___________________________### Data Preparation ###___________________________

for(id in station.ids) {
    
    # specify station name
    station.name <- station.data %>% 
        filter(code == id) %>%
        pull(gw.station)
    
    # print station name
    print(station.name)
    
    # SGI data.... 
    
    # extract output variable, and define drought event base on SGI threshold
    sgi.site <- sgi.data %>%
        filter(station_name == station.name) %>%
        dplyr::select(date, sgi) %>%
        mutate(actual = factor(ifelse(sgi < -1.5,"Drought", "No_Drought"),
                               levels = c("No_Drought", "Drought")))
    
    
    # Meteorological data....
    
    # extract rainfall variable
    rain.site <- precipitation %>%
        filter(gw_station_name == station.name) %>%
        dplyr::select(date, train = rf_value_monthly,
                      train.wk1,
                      train.wk2,
                      train.wk3,
                      train.wk4)
    
    # extract temperature variable
    tmp.site <- temperature %>%
        filter(gw.station == station.name) %>%
        dplyr::select(date, tmp = tmp.value,
                      tmp.wk1,
                      tmp.wk2,
                      tmp.wk3,
                      tmp.wk4)
    
    # convert date field to Date type
    sgi.site$date <- as.Date(sgi.site$date)
    rain.site$date <- as.Date(rain.site$date)
    tmp.site$date <- as.Date(tmp.site$date)
    
    # merge input variable 
    input.site <- rain.site %>% 
        left_join(tmp.site, by = "date")
    
    
    # create variables, with different lags from precipitation and temperature
    
    # precipitation
    lag.rain.site <- rain.site %>% 
        mutate(lag.rain1 = lag(train, 1), # monthly
               lag.rain2 = lag(train, 2),
               cum.rain1 = slide(train, sum, .before= 1),
               cum.rain2 = slide(train, sum, .before= 2),
               cum.rain3 = slide(train, sum, .before= 3),
               cum.rain4 = slide(train, sum, .before= 4),
               cum.rain5 = slide(train, sum, .before= 5),
               cum.rain6 = slide(train, sum, .before= 6),

               lag.rain.wk1 = lag(train.wk1), # weekly
               lag.rain.wk2 = lag(train.wk2),
               lag.rain.wk3 = lag(train.wk3),
               lag.rain.wk4 = lag(train.wk4),
               cum.rain.wk1 = slide(train.wk1, sum, .before= 1),
               cum.rain.wk2 = slide(train.wk2, sum, .before= 2),
               cum.rain.wk3 = slide(train.wk3, sum, .before= 3),
               cum.rain.wk4 = slide(train.wk4, sum, .before= 4)) %>%
        unnest(cols = where(is.list))     # un-list columns
    
    
    # temperature
    lag.tmp.site <- tmp.site %>% 
        mutate(lag.tmp1 = lag(tmp, 1), # monthly
               lag.tmp2 = lag(tmp, 2),
               cum.tmp1 = slide(tmp, mean, .before= 1),
               cum.tmp2 = slide(tmp, mean, .before= 2),
               cum.tmp3 = slide(tmp, mean, .before= 3),
               cum.tmp4 = slide(tmp, mean, .before= 4),
               cum.tmp5 = slide(tmp, mean, .before= 5),
               cum.tmp6 = slide(tmp, mean, .before= 6),
               
               lag.tmp.wk1 = lag(tmp.wk1), # weekly
               lag.tmp.wk2 = lag(tmp.wk2),
               lag.tmp.wk3 = lag(tmp.wk3),
               lag.tmp.wk4 = lag(tmp.wk4),
               cum.tmp.wk1 = slide(tmp.wk1, mean, .before= 1),
               cum.tmp.wk2 = slide(tmp.wk2, mean, .before= 2),
               cum.tmp.wk3 = slide(tmp.wk3, mean, .before= 3),
               cum.tmp.wk4 = slide(tmp.wk4, mean, .before= 4)) %>%
        unnest(cols = where(is.list))     # un-list columns
    
    # merge precipitation, temperature data in one final data frame
    df.final <- lag.rain.site %>%
        left_join(lag.tmp.site, by="date") %>%
        left_join(sgi.site, by="date") %>%
        filter(date > as.Date("2009-12-01")) %>%
        as.data.frame()
    
    
    ## print class distribution
    prop.table(table(df.final$actual))
    
    
    #______________________________Feature Selection________________________________
    
    # # create new data frame for ggplot
    # df.gplot <- df.final %>%
    #     dplyr::select(-date) %>%
    #     melt(id.var = "actual")
    # 
    # # # measure of association between groundwater status and all variables
    # ggplot(data = df.gplot, aes(y = value, x=  actual)) +
    #     geom_boxplot(aes(fill = actual)) +
    #     facet_wrap(~ variable, scales = "free")+
    #     stat_compare_means(aes(label = ..p.signif..), method = "wilcox.test",
    #                        vjust=0.5) + # add p-values
    #     labs(y="Value", x= "Variable")
    # 
    # # select features base on significant level tests (**)
    # df.final <- df.final[,c("actual","lag.rain2", "lag.rain3", "cum.rain2", 
    # "cum.rain3", "cum.rain4", "cum.rain5", "cum.rain6", "cum.rain7","cum.rain8")]
    
    #___________________________Cross Validation____________________________________      
    
    # set a seed for replication
    set.seed(123)
    
    # specify the number of folds
    k = 10
    
    # create color object with k values
    colors = rainbow(k)
    
    # create the folds (k=10)
    folds <- createFolds(y=df.final$actual, k = 10, list = TRUE)
    
    threshold <- 0.5
    ir <- 1.5
    
    # cross validation (k-fold) loop
    cv.results <- lapply(seq_along(folds), function(i) {
        
        # 1. Create train/test folds
        btrain.fold = df.final[-folds[[i]],]                                     
        test.fold   = df.final[folds[[i]],]
        
        #____________________________Pre-processing_____________________________________
        
        # up sample minority classes to 50%
        train.fold <- smote(actual ~., btrain.fold, perc.over = 10, k = 5,
                            perc.under = 1.2)
        
        ## check class distribution
        prop.table(table(train.fold$actual))
        
        # 3. separate train, test sets from the df.final
        x.train <- train.fold[,!colnames(train.fold) %in% c("date", "sgi")]
        
        x.train$actual <- factor(ifelse(x.train$actual == "Drought", 1, 0),
                                 levels = c("0", "1"))
        
        y.train <- factor(ifelse(train.fold$actual =="Drought", 1, 0), 
                          levels = c("0", "1") )
        
        x.test <- test.fold[, !colnames(test.fold) %in% c("actual", "date", "sgi")]
        y.test <- factor(ifelse(test.fold$actual =="Drought", 1, 0), 
                         levels = c("0", "1"))
        
        str(x.train)
        str(y.train)
        #__________________________________Training_____________________________________
        
        # Naive Bayes
        
        # 5. Train Naive Bayes on the SMOTE-balanced fold
        nb.model <- naiveBayes(actual ~ ., data = x.train)
        
        # 6. Predict probability of the positive class ("1" = Drought)
        nb.probs <- predict(nb.model, x.test, type = "raw")[, "1"]
        
        # 7. Create prediction object
        nb.pred <- prediction(predictions =nb.probs, labels = y.test)
        
        # 8. Evaluate Metrics
        nb.auc <- performance(nb.pred, measure = "auc")@y.values[[1]]
        nb.aucpr <- performance(nb.pred, measure = "aucpr")@y.values[[1]]
        nb.ROC <- performance(nb.pred, measure = "tpr", x.measure = "fpr")
        nb.PRC <- performance(nb.pred, measure = "prec", x.measure = "rec")
        
        # 14. Convert predicted probabilities to labels
        nb.label <- factor(ifelse(nb.probs > threshold, 1, 0), levels = c("0", "1"))
        
        # 15. Calculate performance metrics (Accuracy, Precision, Recall, F1)
        nb.cm <- confusionMatrix(data = nb.label, reference = y.test, positive = "1")
        
        # 16. Extract components
        nb.table <- nb.cm$table
        nb.acc <- nb.cm$overall[["Accuracy"]]
        nb.pre <- nb.cm$byClass[["Pos Pred Value"]]
        nb.rec <- nb.cm$byClass[["Sensitivity"]]
        nb.spc <- nb.cm$byClass[["Specificity"]]
        nb.f1 <- ifelse(nb.pre + nb.rec == 0, 0, 2 * (nb.pre * nb.rec) / (nb.pre + nb.rec))
        
        FP <- nb.table["1", "0"]
        TN <- nb.table["0", "0"]
        FN <- nb.table["0", "1"]
        TP <- nb.table["1", "1"]
        
        nb.fpr <- FP / (FP + TN)
        nb.fnr <- FN / (FN + TP)
        
        # Support Vector Machines
        
        # 5. Model train fold
        # 5. Train SVM on the SMOTE-balanced fold (probability = TRUE for AUC)
        svm.model <- svm(actual ~ ., data = x.train, probability = TRUE)
        
        # 6. Predict probability of the positive class ("1" = Drought)
        svm.raw   <- predict(svm.model, x.test, probability = TRUE)
        svm.probs <- attr(svm.raw, "probabilities")[, "1"]
        
        # 7. Create prediction object
        svm.pred <- prediction(predictions =svm.probs, labels = y.test)
        
        # 8. Evaluate Metrics
        svm.auc <- performance(svm.pred, measure = "auc")@y.values[[1]]
        svm.aucpr <- performance(svm.pred, measure = "aucpr")@y.values[[1]]
        svm.ROC <- performance(svm.pred, measure = "tpr", x.measure = "fpr")
        svm.PRC <- performance(svm.pred, measure = "prec", x.measure = "rec")
        
        # 14. Convert predicted probabilities to labels
        svm.label <- factor(ifelse(svm.probs > threshold, 1, 0), levels = c("0", "1"))
        
        # 15. Calculate performance metrics (Accuracy, Precision, Recall, F1)
        svm.cm <- confusionMatrix(data = svm.label, reference = y.test, positive = "1")
        
        # 16. Extract components
        svm.table <- svm.cm$table
        svm.acc <- svm.cm$overall["Accuracy"]
        svm.pre <- svm.cm$byClass[["Pos Pred Value"]]
        svm.rec <- svm.cm$byClass[["Sensitivity"]]
        svm.f1 <- ifelse(svm.pre + svm.rec == 0, 0, 2 * (svm.pre * svm.rec) / (svm.pre + svm.rec))
        svm.spc <- svm.cm$byClass[["Specificity"]]
        
        FP <- svm.table["1", "0"]
        TN <- svm.table["0", "0"]
        FN <- svm.table["0", "1"]
        TP <- svm.table["1", "1"]
        
        svm.fpr <- FP / (FP + TN)
        svm.fnr <- FN / (FN + TP)
        
        #CART
        
        # 5. Model train fold
        # 5. Train CART on the SMOTE-balanced fold
        c.model <- rpart(actual ~ ., data = x.train, method = "class")
        
        # 6. Predict probability of the positive class ("1" = Drought)
        c.probs <- predict(c.model, x.test, type = "prob")[, "1"]
        
        # 7. Create prediction object
        c.pred <- prediction(predictions =c.probs, labels = y.test)
        
        # 8. Evaluate Metrics
        c.auc <- performance(c.pred, measure = "auc")@y.values[[1]]
        c.aucpr <- performance(c.pred, measure = "aucpr")@y.values[[1]]
        c.ROC <- performance(c.pred, measure = "tpr", x.measure = "fpr")
        c.PRC <- performance(c.pred, measure = "prec", x.measure = "rec")
        
        # 14. Convert predicted probabilities to labels
        c.label <- factor(ifelse(c.probs > threshold, 1, 0), levels = c("0", "1"))
        
        # 15. Calculate performance metrics (Accuracy, Precision, Recall, F1)
        c.cm <- confusionMatrix(data = c.label, reference = y.test, positive = "1")
        
        # 16. Extract components
        c.table <- c.cm$table
        c.acc <- c.cm$overall["Accuracy"]
        c.pre <- c.cm$byClass[["Pos Pred Value"]]
        c.rec <- c.cm$byClass[["Sensitivity"]]
        c.f1 <- ifelse(c.pre + c.rec == 0, 0, 2 * (c.pre * c.rec) / (c.pre + c.rec))
        c.spc <- c.cm$byClass[["Specificity"]]
        
        FP <- c.table["1", "0"]
        TN <- c.table["0", "0"]
        FN <- c.table["0", "1"]
        TP <- c.table["1", "1"]
        
        c.fpr <- FP / (FP + TN)
        c.fnr <- FN / (FN + TP)
        
        # Decision trees
        
        # # 5. Model train fold
        # 5. Train C5.0 decision tree on the SMOTE-balanced fold
        tree.model <- C5.0(actual ~ ., data = x.train)
        
        # 6. Predict probability of the positive class ("1" = Drought)
        tree.probs <- predict(tree.model, x.test, type = "prob")[, "1"]
        
        # 7. Create prediction object
        tree.pred <- prediction(predictions =tree.probs, labels = y.test)
        
        # 8. Evaluate Metrics
        tree.auc <- performance(tree.pred, measure = "auc")@y.values[[1]]
        tree.aucpr <- performance(tree.pred, measure = "aucpr")@y.values[[1]]
        tree.ROC <- performance(tree.pred, measure = "tpr", x.measure = "fpr")
        tree.PRC <- performance(tree.pred, measure = "prec", x.measure = "rec")
        
        # 14. Convert predicted probabilities to labels
        tree.label <- factor(ifelse(tree.probs > threshold, 1, 0), levels = c("0", "1"))
        
        # 15. Calculate performance metrics (Accuracy, Precision, Recall, F1)
        tree.cm <- confusionMatrix(data = tree.label, reference = y.test, positive = "1")
        
        # 16. Extract components
        tree.table <- tree.cm$table
        tree.acc <- tree.cm$overall["Accuracy"]
        tree.pre <- tree.cm$byClass[["Pos Pred Value"]]
        tree.rec <- tree.cm$byClass[["Sensitivity"]]
        tree.f1 <- ifelse(tree.pre + tree.rec == 0, 0, 2 * (tree.pre * tree.rec) / (tree.pre + tree.rec))
        tree.spc <- tree.cm$byClass[["Specificity"]]
        
        FP <- tree.table["1", "0"]
        TN <- tree.table["0", "0"]
        FN <- tree.table["0", "1"]
        TP <- tree.table["1", "1"]
        
        tree.fpr <- FP / (FP + TN)
        tree.fnr <- FN / (FN + TP)
        
        
        # Random Forest
        
        # 5. Model train fold
        # 5. Train Random Forest on the SMOTE-balanced fold
        rf.model <- randomForest(actual ~ ., data = x.train, ntree = 100)
        
        # 6. Predict probability of the positive class ("1" = Drought)
        rf.probs <- predict(rf.model, x.test, type = "prob")[, "1"]
        
        # 7. Create prediction object
        rf.pred <- prediction(predictions =rf.probs, labels = y.test)
        
        # 8. Evaluate Metrics
        rf.auc <- performance(rf.pred, measure = "auc")@y.values[[1]]
        rf.aucpr <- performance(rf.pred, measure = "aucpr")@y.values[[1]]
        rf.ROC <- performance(rf.pred, measure = "tpr", x.measure = "fpr")
        rf.PRC <- performance(rf.pred, measure = "prec", x.measure = "rec")
        
        # 14. Convert predicted probabilities to labels
        rf.label <- factor(ifelse(rf.probs > threshold, 1, 0), levels = c("0", "1"))
        
        # 15. Calculate performance metrics (Accuracy, Precision, Recall, F1)
        rf.cm <- confusionMatrix(data = rf.label, reference = y.test, positive = "1")
        
        # 16. Extract components
        rf.table <- rf.cm$table
        rf.acc <- rf.cm$overall["Accuracy"]
        rf.pre <- rf.cm$byClass[["Pos Pred Value"]]
        rf.rec <- rf.cm$byClass[["Sensitivity"]]
        rf.f1 <- ifelse(rf.pre + rf.rec == 0, 0, 2 * (rf.pre * rf.rec) / (rf.pre + rf.rec))
        rf.spc <- rf.cm$byClass[["Specificity"]]
        
        FP <- rf.table["1", "0"]
        TN <- rf.table["0", "0"]
        FN <- rf.table["0", "1"]
        TP <- rf.table["1", "1"]
        
        rf.fpr <- FP / (FP + TN)
        rf.fnr <- FN / (FN + TP)
        
        
        #XGBoost
        
        # 1. Convert categorical features to dummy type
        # since XGB only works with numerical values.
        x.train <- train.fold[,!colnames(train.fold) %in% c("actual","date", "sgi")]
        y.train <- ifelse(train.fold$actual == "Drought", 1,0)
        
        x.test <- test.fold[, !colnames(test.fold) %in% c("actual", "date", "sgi")]
        y.test <-  factor(ifelse(test.fold$actual == "Drought", 1,0), 
                          levels = c("0", "1")) 
        
        
        # 2. Convert input data to matrices as required in XGBoost
        mx.train <- xgb.DMatrix(data = as.matrix(x.train),
                                label = y.train)
        
        mx.test <- xgb.DMatrix(data = as.matrix(x.test),
                               label = y.test)
        
        # 4. Set hyper parameters
        params <- list(
            eta = 0.3,
            max_depth = 6,
            subsample = 1,
            colsample_bytree = 1,
            min_child_weight = 1,
            gamma = 0,
            objective = "binary:logistic",
            eval_metric = "auc",
            booster = "gbtree",
            alpha = 0,
            lambda = 1
        )
        
        # 5. Train XGBoost model
        xgb.model <- xgb.train(
            data = mx.train,
            nrounds = 500,
            params = params,
            verbose = 0
        )
        
        # 6. Predict test fold probabilities
        xgb.predict <- predict(xgb.model, mx.test)
        
        # 7. Create prediction object
        xgb.pred <- prediction(xgb.predict, y.test)
        
        # 8. Create evaluation objects
        xgb.auc <- performance(xgb.pred, measure = "auc")@y.values[[1]]
        xgb.aucpr <- performance(xgb.pred, measure = "aucpr")@y.values[[1]]
        xgb.ROC <- performance(xgb.pred, measure = "tpr", x.measure = "fpr")
        xgb.PRC <- performance(xgb.pred, measure = "prec", x.measure = "rec")
        
        # 14. Convert predicted probabilities to labels
        xgb.label <- factor(ifelse(xgb.predict > threshold, 1, 0), levels = c("0","1"))
        
        # 15. Calculate pexgbormance metrics (Accuracy, Precision, Recall, F1)
        xgb.cm <- confusionMatrix(data = xgb.label, reference = y.test, positive = "1")
        
        # 16. Extract components
        xgb.table <- xgb.cm$table
        xgb.acc <- xgb.cm$overall["Accuracy"]
        xgb.pre <- xgb.cm$byClass[["Pos Pred Value"]]
        xgb.rec <- xgb.cm$byClass[["Sensitivity"]]
        xgb.f1 <- ifelse(xgb.pre + xgb.rec == 0, 0, 2 * (xgb.pre * xgb.rec) / (xgb.pre + xgb.rec))
        xgb.spc <- xgb.cm$byClass[["Specificity"]]
        
        FP <- xgb.table["1", "0"]
        TN <- xgb.table["0", "0"]
        FN <- xgb.table["0", "1"]
        TP <- xgb.table["1", "1"]
        
        xgb.fpr <- FP / (FP + TN)
        xgb.fnr <- FN / (FN + TP)
        
        #_______________________________Data Saving_____________________________________
        
        # 9. Store metrics
        list(
            
            xgb.auc = xgb.auc,
            xgb.aucpr = xgb.aucpr,
            xgb.ROC = xgb.ROC,
            xgb.PRC = xgb.PRC,
            xgb.acc = xgb.acc,
            xgb.pre = xgb.pre,
            xgb.rec = xgb.rec,
            xgb.f1  = xgb.f1,
            xgb.fpr = xgb.fpr,
            xgb.fnr = xgb.fnr,
            
            nb.auc = nb.auc,
            nb.aucpr = nb.aucpr,
            nb.ROC = nb.ROC,
            nb.PRC = nb.PRC,
            nb.acc = nb.acc,
            nb.pre = nb.pre,
            nb.rec = nb.rec,
            nb.f1  = nb.f1,
            nb.fpr = nb.fpr,
            nb.fnr = nb.fnr,
            
            svm.auc = svm.auc,
            svm.aucpr = svm.aucpr,
            svm.ROC = svm.ROC,
            svm.PRC = svm.PRC,
            svm.acc = svm.acc,
            svm.pre = svm.pre,
            svm.rec = svm.rec,
            svm.f1  = svm.f1,
            svm.fpr = svm.fpr,
            svm.fnr = svm.fnr,
            
            c.auc = c.auc,
            c.aucpr = c.aucpr,
            c.ROC = c.ROC,
            c.PRC = c.PRC,
            c.acc = c.acc,
            c.pre = c.pre,
            c.rec = c.rec,
            c.f1  = c.f1,
            c.fpr = c.fpr,
            c.fnr = c.fnr,
            
            tree.auc = tree.auc,
            tree.aucpr = tree.aucpr,
            tree.ROC = tree.ROC,
            tree.PRC = tree.PRC,
            tree.acc = tree.acc,
            tree.pre = tree.pre,
            tree.rec = tree.rec,
            tree.f1  = tree.f1,
            tree.fpr = tree.fpr,
            tree.fnr = tree.fnr,
            
            rf.auc = rf.auc,
            rf.aucpr = rf.aucpr,
            rf.ROC = rf.ROC,
            rf.PRC = rf.PRC,
            rf.acc = rf.acc,
            rf.pre = rf.pre,
            rf.rec = rf.rec,
            rf.f1  = rf.f1,
            rf.fpr = rf.fpr,
            rf.fnr = rf.fnr
        )
        
    })
    
    
    # extract results
    auc.results <- rbind(auc.results, data.frame(
        id = id,
        nb.auc = mean(sapply(cv.results, function(res) res$nb.auc)),
        svm.auc = mean(sapply(cv.results, function(res) res$svm.auc)),
        c.auc = mean(sapply(cv.results, function(res) res$c.auc)),
        tree.auc = mean(sapply(cv.results, function(res) res$tree.auc)),
        rf.auc = mean(sapply(cv.results, function(res) res$rf.auc)),
        xgb.auc = mean(sapply(cv.results, function(res) res$xgb.auc)),
        
        nb.aucpr = mean(sapply(cv.results, function(res) res$nb.aucpr)),
        svm.aucpr = mean(sapply(cv.results, function(res) res$svm.aucpr)),
        c.aucpr = mean(sapply(cv.results, function(res) res$c.aucpr)),
        tree.aucpr = mean(sapply(cv.results, function(res) res$tree.aucpr)),
        rf.aucpr = mean(sapply(cv.results, function(res) res$rf.aucpr)),
        xgb.aucpr = mean(sapply(cv.results, function(res) res$xgb.aucpr))
    ))
    
    
    # extract results precision - recall
    prc.results <- rbind(prc.results, data.frame(
        id = id,
        nb.pre = mean(sapply(cv.results, function(res) res$nb.pre)),
        svm.pre = mean(sapply(cv.results, function(res) res$svm.pre)),
        c.pre = mean(sapply(cv.results, function(res) res$c.pre)),
        tree.pre = mean(sapply(cv.results, function(res) res$tree.pre)),
        rf.pre = mean(sapply(cv.results, function(res) res$rf.pre)),
        xgb.pre = mean(sapply(cv.results, function(res) res$xgb.pre)),
        
        nb.rec = mean(sapply(cv.results, function(res) res$nb.rec)),
        svm.rec = mean(sapply(cv.results, function(res) res$svm.rec)),
        c.rec = mean(sapply(cv.results, function(res) res$c.rec)),
        tree.rec = mean(sapply(cv.results, function(res) res$tree.rec)),
        rf.rec = mean(sapply(cv.results, function(res) res$rf.rec)),
        xgb.rec = mean(sapply(cv.results, function(res) res$xgb.rec)),
        
        nb.f1 = mean(sapply(cv.results, function(res) res$nb.f1)),
        svm.f1 = mean(sapply(cv.results, function(res) res$svm.f1)),
        c.f1 = mean(sapply(cv.results, function(res) res$c.f1)),
        tree.f1 = mean(sapply(cv.results, function(res) res$tree.f1)),
        rf.f1 = mean(sapply(cv.results, function(res) res$rf.f1)),
        xgb.f1 = mean(sapply(cv.results, function(res) res$xgb.f1))
    ))
    
    
    # extract results
    error.results <- rbind(error.results, data.frame(
        id = id,
        nb.fpr = mean(sapply(cv.results, function(res) res$nb.fpr)),
        svm.fpr = mean(sapply(cv.results, function(res) res$svm.fpr)),
        c.fpr = mean(sapply(cv.results, function(res) res$c.fpr)),
        tree.fpr = mean(sapply(cv.results, function(res) res$tree.fpr)),
        rf.fpr = mean(sapply(cv.results, function(res) res$rf.fpr)),
        xgb.fpr = mean(sapply(cv.results, function(res) res$xgb.fpr)),
        
        nb.fnr = mean(sapply(cv.results, function(res) res$nb.fnr)),
        svm.fnr = mean(sapply(cv.results, function(res) res$svm.fnr)),
        c.fnr = mean(sapply(cv.results, function(res) res$c.fnr)),
        tree.fnr = mean(sapply(cv.results, function(res) res$tree.fnr)),
        rf.fnr = mean(sapply(cv.results, function(res) res$rf.fnr)),
        xgb.fnr = mean(sapply(cv.results, function(res) res$xgb.fnr))
    ))
    
}


#__________________________________Data Visualization___________________________


# 12. Reshape AUC data for ggplot
auc.melted <- melt(auc.results,
                   measure.vars = c("xgb.auc","nb.auc", "svm.auc", "c.auc", 
                                    "tree.auc", "rf.auc", 
                                    "xgb.aucpr","nb.aucpr", "svm.aucpr",
                                    "c.aucpr", "tree.aucpr",
                                    "rf.aucpr"),
                   variable.name = "model.metric", 
                   value.name = "auc")

auc.melted$model <- gsub("\\..*", "", auc.melted$model.metric)
auc.melted$metric <- gsub(".*\\.", "", auc.melted$model.metric)


# 3. Set the factor levels for 'Model' to ensure the correct order in the plot
auc.melted$model <- factor(auc.melted$model, levels = c("xgb","nb", "svm", "c",
                                                        "tree", "rf"))

# 4. Set the factor levels for 'Metric' (auc, aucpr)
auc.melted$metric <- factor(auc.melted$metric, levels = c("auc", "aucpr"))

# 5. Plot Precision, Recall, and F1 Score for each model side by side
ggplot(auc.melted, aes(x = model, y = auc, fill = metric)) +
    geom_boxplot() +
    theme_minimal() +
    labs(
        x = "Model", 
        y = "AUC") +
    scale_x_discrete(labels = c("xgb" = "XGB",
                                "nb" = "Naïve Bayes", 
                                "svm" = "SVM", 
                                "c" = "CART", 
                                "tree" = "Decision Trees(C5.0)", 
                                "rf" = "Random Forest")) +
    scale_fill_manual(values = c("auc" = "#00b0f6", "aucpr" = "#f8766d"),
                      labels = c("auc" = "ROC", "aucpr" = "Precision-Recall")) +
    theme(legend.position = "top", legend.title = element_blank())




# 1. Reshape Precision, Recall, and F1 Score data for ggplot
prc.melted <- melt(prc.results,
                   measure.vars = c("xgb.pre","nb.pre", "svm.pre", "c.pre", "tree.pre", "rf.pre", 
                                    "xgb.rec", "nb.rec", "svm.rec", "c.rec", "tree.rec", "rf.rec", 
                                    "xgb.f1", "nb.f1", "svm.f1", "c.f1", "tree.f1", "rf.f1"), 
                   variable.name = "model.metric", 
                   value.name = "score")

# 2. Extract Metric and Model Information
prc.melted$metric <- gsub(".*\\.", "", prc.melted$model.metric)
prc.melted$model <- gsub("\\..*", "", prc.melted$model.metric)

# 3. Set the factor levels for 'Model' to ensure the correct order in the plot
prc.melted$model <- factor(prc.melted$model, levels = c("xgb","nb", "svm", "c", "tree", "rf"))

# 4. Set the factor levels for 'Metric' (Precision, Recall, F1 Score)
prc.melted$Metric <- factor(prc.melted$metric, levels = c("pre", "rec", "f1"))

# 5. Plot Precision, Recall, and F1 Score for each model side by side
ggplot(prc.melted, aes(x = model, y = score, fill = metric)) +
    geom_boxplot() +
    theme_minimal() +
    labs(
        x = "Model", 
        y = "Score") +
    scale_x_discrete(labels = c(
        "xgb" = "XGBoost",
        "nb" = "Naïve Bayes", 
        "svm" = "SVM", 
        "c" = "CART", 
        "tree" = "Decision Trees (C5.0)", 
        "rf" = "Random Forest")) +
    scale_fill_manual(values = c("pre" = "#00b0f6", "rec" = "#00bf7d", "f1" = "#f8766d"),
                      labels = c("pre" = "Precision", "rec" = "Recall", "f1" = "F1 Score")) +
    theme(legend.position = "top", legend.title = element_blank())




# 12. Reshape AUC data for ggplot
error.melted <- melt(error.results,
                     measure.vars = c("xgb.fpr","nb.fpr", "svm.fpr", "c.fpr", "tree.fpr", "rf.fpr", 
                                      "xgb.fnr","nb.fnr", "svm.fnr", "c.fnr", "tree.fnr", "rf.fnr"),
                     variable.name = "model.metric", 
                     value.name = "rate")



# 2. Extract Metric and Model Information
error.melted$metric <- gsub(".*\\.", "", error.melted$model.metric)
error.melted$model <- gsub("\\..*", "", error.melted$model.metric)

# 3. Set the factor levels for 'Model' to ensure the correct order in the plot
error.melted$model <- factor(error.melted$model, levels = c("xgb","nb", "svm", "c", "tree", "rf"))

# 4. Set the factor levels for 'Metric' (Precision, Recall, F1 Score)
error.melted$metric <- factor(error.melted$metric, levels = c("fpr", "fnr"))


# 5. Plot Precision, Recall, and F1 Score for each model side by side
ggplot(error.melted, aes(x = model, y = rate, fill = metric)) +
    geom_boxplot() +
    theme_minimal() +
    labs(
        x = "Model", 
        y = "Rate") +
    scale_x_discrete(labels = c("xgb" = "XGBoost",
                                "nb" = "Naïve Bayes", 
                                "svm" = "SVM", 
                                "c" = "CART", 
                                "tree" = "Decision Trees(C5.0)", 
                                "rf" = "Random Forest")) +
    scale_fill_manual(values = c("fpr" = "#00b0f6", "fnr" = "#f8766d"),
                      labels = c("fpr" = "False Positive", "fnr" = "False Negative")) +
    theme(legend.position = "top", legend.title = element_blank())



#____________________________Data Writing_______________________________________

# 18. write files
dir.create("../outputs", showWarnings = FALSE, recursive = TRUE)
write.csv(auc.results, "../outputs/site_level_auc_results.csv", row.names = FALSE)

write.csv(prc.results, "../outputs/site_level_prc_results.csv", row.names = FALSE)

write.csv(error.results, "../outputs/site_level_error_results.csv", row.names = FALSE)
