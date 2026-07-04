# =============================================================================
# Groundwater Drought Prediction — Consolidated Modelling Pipeline
#
# =============================================================================
# LIBRARIES
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
library(forcats)
library(e1071)
library(xgboost)
library(caret)
library(rpart)
library(rpart.plot)
library(randomForest)
library(vip)
library(ranger)
library(glmnet)
library(gbm)
library(MLmetrics)
library(ebmc)
library(UBL)
library(mboost)
library(MLeval)
library(themis)
library(VSURF)
library(adabag)
library(keras)
library(nnet)
library(NeuralNetTools)
library(patchwork)

# performance evaluation
library(performanceEstimation) # smote function is here
library(splitstackshape)
library(ROCR)
library(pROC)
library(MLmetrics)

# =============================================================================
# FUNCTIONS  
# =============================================================================

# RUSBoosting function
rusboost <- function(algorithm, data, ir = 1, ntree = 300, k_folds = 10, do_plot = TRUE) {
  
  # Load required packages
  require(ebmc)
  require(ROCR)
  require(ggplot2)
  
  # Validate algorithm choice
  valid_algs <- c("cart", "c50", "rf", "nb", "svm")
  
  if(!(algorithm %in% valid_algs)) {
    stop("Invalid algorithm. Choose from: cart, c50, rf, nb, svm")
  }
  
  # Setup cross-validation
  set.seed(123)
  n <- nrow(data$x)
  folds <- sample(rep(1:k_folds, length.out = n))
  
  # Store performance metrics
  cv_results <- list(
    accuracy = numeric(k_folds),
    sensitivity = numeric(k_folds),
    specificity = numeric(k_folds),
    precision = numeric(k_folds),
    f1 = numeric(k_folds),
    auc = numeric(k_folds),
    aucpr = numeric(k_folds)
  )
  
  # For storing all fold predictions for overall assessment
  all_preds <- vector("list", k_folds)
  all_actuals <- vector("list", k_folds)
  
  # Run k-fold cross-validation
  for(i in 1:k_folds) {
    
    # Split data into training and testing sets
    train_idx <- which(folds != i)
    test_idx <- which(folds == i)
    
    # Create training data
    train_x <- data$x[train_idx, , drop = FALSE]
    train_y <- data$y[train_idx]
    
    # Convert to data frame for rus function
    train_data <- data.frame(
      train_x,
      actual = factor(ifelse(train_y == "Drought", 1, 0), levels = c(0, 1))
    )
    
    # Create testing data
    test_x <- data$x[test_idx, , drop = FALSE]
    test_y <- data$y[test_idx]
    test_data <- data.frame(test_x)
    
    # Train the model using rus function
    model <- rus(actual ~ ., 
                 data = train_data, 
                 size = 20, 
                 alg = algorithm, 
                 ir = ir, 
                 rf.ntree = ntree)
    
    # Make predictions on test set
    model_probs <- predict(model, test_data, type = "prob")
    model_preds <- ifelse(model_probs > 0.5, "Drought", "No_Drought")
    
    # Create prediction object for ROCR
    model_pred <- prediction(predictions = model_probs, 
                             labels = ifelse(test_y == "Drought", 1, 0))
    
    # Store predictions and actuals for later analysis
    all_preds[[i]] <- model_probs
    all_actuals[[i]] <- ifelse(test_y == "Drought", 1, 0)
    
    # Calculate performance metrics
    auc <- performance(model_pred, measure = "auc")@y.values[[1]]
    aucpr <- performance(model_pred, measure = "aucpr")@y.values[[1]]
    
    # For other metrics, we need to pick an optimal threshold
    # Here using 0.5 as the default threshold
    conf_matrix <- table(Actual = test_y, 
                         Predicted = model_preds)
    
    # Calculate metrics from confusion matrix
    if (nrow(conf_matrix) == 2 && ncol(conf_matrix) == 2) {
      TP <- conf_matrix["Drought", "Drought"]
      TN <- conf_matrix["No_Drought", "No_Drought"]
      FP <- conf_matrix["No_Drought", "Drought"]
      FN <- conf_matrix["Drought", "No_Drought"]
      
      # Handle potential division by zero
      acc <- (TP + TN) / sum(conf_matrix)
      sens <- ifelse(TP + FN > 0, TP / (TP + FN), NA)
      spec <- ifelse(TN + FP > 0, TN / (TN + FP), NA)
      prec <- ifelse(TP + FP > 0, TP / (TP + FP), NA)
      f1 <- ifelse(prec + sens > 0, 2 * prec * sens / (prec + sens), NA)
    } else {
      # In case we don't have both classes in the test set
      acc <- sum(diag(conf_matrix)) / sum(conf_matrix)
      sens <- NA
      spec <- NA
      prec <- NA
      f1 <- NA
    }
    
    # Store metrics
    cv_results$accuracy[i] <- acc
    cv_results$sensitivity[i] <- sens
    cv_results$specificity[i] <- spec
    cv_results$precision[i] <- prec
    cv_results$f1[i] <- f1
    cv_results$auc[i] <- auc
    cv_results$aucpr[i] <- aucpr
  }  # End of for loop
  
  # Combine all predictions and actuals for overall evaluation
  combined_preds <- unlist(all_preds)
  combined_actuals <- unlist(all_actuals)
  
  # Create combined prediction object for plotting
  combined_pred_obj <- prediction(predictions = combined_preds, 
                                  labels = combined_actuals)
  
  # Create ROC and PRC curves
  roc_perf <- performance(combined_pred_obj, measure = "tpr", x.measure = "fpr")
  prc_perf <- performance(combined_pred_obj, measure = "prec", x.measure = "rec")
  
  # Calculate overall AUC and AUCPR
  overall_auc <- performance(combined_pred_obj, measure = "auc")@y.values[[1]]
  overall_aucpr <- performance(combined_pred_obj, measure = "aucpr")@y.values[[1]]
  
  # Create plot functions
  plot_roc <- function() {
    # Extract data points for plotting
    roc_data <- data.frame(
      FPR = roc_perf@x.values[[1]],
      TPR = roc_perf@y.values[[1]]
    )
    
    # Plot ROC curve with ggplot2
    roc_plot <- ggplot(roc_data, aes(x = FPR, y = TPR)) +
      geom_line(color = "blue", linewidth = 1) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray") +
      labs(
        x = "False Positive Rate",
        y = "True Positive Rate"
      ) +
      theme_bw() +
      theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) +
      coord_equal() +
      annotate("text", x = 0.75, y = 0.25, 
               label = paste("Mean AUCROC =", round(overall_auc, 2)), 
               color = "blue")
    
    return(roc_plot)
  }
  
  plot_prc <- function() {
    # Extract data points for plotting
    prc_data <- data.frame(
      Recall = prc_perf@x.values[[1]],
      Precision = prc_perf@y.values[[1]]
    )
    
    # Filter out NA values (can occur at endpoints)
    prc_data <- prc_data[!is.na(prc_data$Precision), ]
    
    # Calculate prevalence (proportion of positive class)
    prevalence <- mean(combined_actuals, na.rm = TRUE)
    
    # Plot PR curve with ggplot2
    prc_plot <- ggplot(prc_data, aes(x = Recall, y = Precision)) +
      geom_line(color = "red", linewidth = 1) +
      geom_hline(yintercept = prevalence, linetype = "dashed", color = "gray") +
      labs(
        x = "Recall",
        y = "Precision"
      ) +
      theme_bw() +
      theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) +
      coord_cartesian(ylim = c(0, 1)) +
      annotate("text", x = 0.75, y = 0.25, 
               label = paste("Mean AUCPR =", round(overall_aucpr, 2)), 
               color = "red")
    
    return(prc_plot)
  }
  
  # Plot if requested
  if(isTRUE(do_plot)) {
    # Print ROC and PRC plots
    print(plot_roc())
    print(plot_prc())
  }
  
  # Train final model on all data
  full_data <- data.frame(
    data$x,
    actual = factor(ifelse(data$y == "Drought", 1, 0), levels = c(0, 1))
  )
  
  final_model <- rus(actual ~ ., 
                     data = full_data, 
                     size = 20, 
                     alg = algorithm, 
                     ir = ir, 
                     rf.ntree = ntree)
  
  # Return results
  return(list(
    cv_metrics = list(
      accuracy = mean(cv_results$accuracy, na.rm = TRUE),
      sensitivity = mean(cv_results$sensitivity, na.rm = TRUE),
      specificity = mean(cv_results$specificity, na.rm = TRUE),
      precision = mean(cv_results$precision, na.rm = TRUE),
      f1 = mean(cv_results$f1, na.rm = TRUE),
      auc = mean(cv_results$auc, na.rm = TRUE),
      aucpr = mean(cv_results$aucpr, na.rm = TRUE)
    ),
    overall_metrics = list(
      auc = overall_auc,
      aucpr = overall_aucpr
    ),
    cv_results = cv_results,
    final_model = final_model,
    all_predictions = all_preds,
    all_actuals = all_actuals,
    plot_roc = plot_roc,
    plot_prc = plot_prc,
    call = match.call()
  ))
}

# SMOTEBoosting function
smoteboost <- function(algorithm, data, over, ntree = 300, k_folds = 10, do_plot = TRUE) {
  
  # Load required packages
  require(ebmc)
  require(ROCR)
  require(ggplot2)
  
  # Validate algorithm choice
  valid_algs <- c("cart", "c50", "rf", "nb", "svm")
  
  if(!(algorithm %in% valid_algs)) {
    stop("Invalid algorithm. Choose from: cart, c50, rf, nb, svm")
  }
  
  # Setup cross-validation
  set.seed(123)
  n <- nrow(data$x)
  folds <- sample(rep(1:k_folds, length.out = n))
  
  # Store performance metrics
  cv_results <- list(
    accuracy = numeric(k_folds),
    sensitivity = numeric(k_folds),
    specificity = numeric(k_folds),
    precision = numeric(k_folds),
    f1 = numeric(k_folds),
    auc = numeric(k_folds),
    aucpr = numeric(k_folds)
  )
  
  # For storing all fold predictions for overall assessment
  all_preds <- vector("list", k_folds)
  all_actuals <- vector("list", k_folds)
  
  # Run k-fold cross-validation
  for(i in 1:k_folds) {
    
    # Split data into training and testing sets
    train_idx <- which(folds != i)
    test_idx <- which(folds == i)
    
    # Create training data
    train_x <- data$x[train_idx, , drop = FALSE]
    train_y <- data$y[train_idx]
    
    # Convert to data frame for rus function
    train_data <- data.frame(
      train_x,
      actual = factor(ifelse(train_y == "Drought", 1, 0), levels = c(0, 1))
    )
    
    # Create testing data
    test_x <- data$x[test_idx, , drop = FALSE]
    test_y <- data$y[test_idx]
    test_data <- data.frame(test_x)
    
    # Train the model using rus function
    model <- sbo(actual ~ ., 
                 data = train_data, 
                 size = 20, 
                 alg = algorithm, 
                 over = over, 
                 rf.ntree = ntree)
    
    # Make predictions on test set
    model_probs <- predict(model, test_data, type = "prob")
    model_preds <- ifelse(model_probs > 0.5, "Drought", "No_Drought")
    
    # Create prediction object for ROCR
    model_pred <- prediction(predictions = model_probs, 
                             labels = ifelse(test_y == "Drought", 1, 0))
    
    # Store predictions and actuals for later analysis
    all_preds[[i]] <- model_probs
    all_actuals[[i]] <- ifelse(test_y == "Drought", 1, 0)
    
    # Calculate performance metrics
    auc <- performance(model_pred, measure = "auc")@y.values[[1]]
    aucpr <- performance(model_pred, measure = "aucpr")@y.values[[1]]
    
    # For other metrics, we need to pick an optimal threshold
    # Here using 0.5 as the default threshold
    conf_matrix <- table(Actual = test_y, 
                         Predicted = model_preds)
    
    # Calculate metrics from confusion matrix
    if (nrow(conf_matrix) == 2 && ncol(conf_matrix) == 2) {
      TP <- conf_matrix["Drought", "Drought"]
      TN <- conf_matrix["No_Drought", "No_Drought"]
      FP <- conf_matrix["No_Drought", "Drought"]
      FN <- conf_matrix["Drought", "No_Drought"]
      
      # Handle potential division by zero
      acc <- (TP + TN) / sum(conf_matrix)
      sens <- ifelse(TP + FN > 0, TP / (TP + FN), NA)
      spec <- ifelse(TN + FP > 0, TN / (TN + FP), NA)
      prec <- ifelse(TP + FP > 0, TP / (TP + FP), NA)
      f1 <- ifelse(prec + sens > 0, 2 * prec * sens / (prec + sens), NA)
    } else {
      # In case we don't have both classes in the test set
      acc <- sum(diag(conf_matrix)) / sum(conf_matrix)
      sens <- NA
      spec <- NA
      prec <- NA
      f1 <- NA
    }
    
    # Store metrics
    cv_results$accuracy[i] <- acc
    cv_results$sensitivity[i] <- sens
    cv_results$specificity[i] <- spec
    cv_results$precision[i] <- prec
    cv_results$f1[i] <- f1
    cv_results$auc[i] <- auc
    cv_results$aucpr[i] <- aucpr
  }  # End of for loop
  
  # Combine all predictions and actuals for overall evaluation
  combined_preds <- unlist(all_preds)
  combined_actuals <- unlist(all_actuals)
  
  # Create combined prediction object for plotting
  combined_pred_obj <- prediction(predictions = combined_preds, 
                                  labels = combined_actuals)
  
  # Create ROC and PRC curves
  roc_perf <- performance(combined_pred_obj, measure = "tpr", x.measure = "fpr")
  prc_perf <- performance(combined_pred_obj, measure = "prec", x.measure = "rec")
  
  # Calculate overall AUC and AUCPR
  overall_auc <- performance(combined_pred_obj, measure = "auc")@y.values[[1]]
  overall_aucpr <- performance(combined_pred_obj, measure = "aucpr")@y.values[[1]]
  
  # Create plot functions
  plot_roc <- function() {
    # Extract data points for plotting
    roc_data <- data.frame(
      FPR = roc_perf@x.values[[1]],
      TPR = roc_perf@y.values[[1]]
    )
    
    # Plot ROC curve with ggplot2
    roc_plot <- ggplot(roc_data, aes(x = FPR, y = TPR)) +
      geom_line(color = "blue", linewidth = 1) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray") +
      labs(
        x = "False Positive Rate",
        y = "True Positive Rate"
      ) +
      theme_minimal() +
      coord_equal() +
      annotate("text", x = 0.75, y = 0.25, 
               label = paste("AUC =", round(overall_auc, 3)), 
               color = "blue")
    
    return(roc_plot)
  }
  
  plot_prc <- function() {
    # Extract data points for plotting
    prc_data <- data.frame(
      Recall = prc_perf@x.values[[1]],
      Precision = prc_perf@y.values[[1]]
    )
    
    # Filter out NA values (can occur at endpoints)
    prc_data <- prc_data[!is.na(prc_data$Precision), ]
    
    # Calculate prevalence (proportion of positive class)
    prevalence <- mean(combined_actuals, na.rm = TRUE)
    
    # Plot PR curve with ggplot2
    prc_plot <- ggplot(prc_data, aes(x = Recall, y = Precision)) +
      geom_line(color = "red", linewidth = 1) +
      geom_hline(yintercept = prevalence, linetype = "dashed", color = "gray") +
      labs(
        x = "Recall",
        y = "Precision"
      ) +
      theme_minimal() +
      coord_cartesian(ylim = c(0, 1)) +
      annotate("text", x = 0.75, y = 0.25, 
               label = paste("AUCPR =", round(overall_aucpr, 3)), 
               color = "red")
    
    return(prc_plot)
  }
  
  # Plot if requested
  if(isTRUE(do_plot)) {
    # Print ROC and PRC plots
    print(plot_roc())
    print(plot_prc())
  }
  
  # Train final model on all data
  full_data <- data.frame(
    data$x,
    actual = factor(ifelse(data$y == "Drought", 1, 0), levels = c(0, 1))
  )
  
  final_model <- sbo(actual ~ ., 
                     data = full_data, 
                     size = 20, 
                     alg = algorithm, 
                     over = over, 
                     rf.ntree = ntree)
  
  # Return results
  return(list(
    cv_metrics = list(
      accuracy = mean(cv_results$accuracy, na.rm = TRUE),
      sensitivity = mean(cv_results$sensitivity, na.rm = TRUE),
      specificity = mean(cv_results$specificity, na.rm = TRUE),
      precision = mean(cv_results$precision, na.rm = TRUE),
      f1 = mean(cv_results$f1, na.rm = TRUE),
      auc = mean(cv_results$auc, na.rm = TRUE),
      aucpr = mean(cv_results$aucpr, na.rm = TRUE)
    ),
    overall_metrics = list(
      auc = overall_auc,
      aucpr = overall_aucpr
    ),
    cv_results = cv_results,
    final_model = final_model,
    all_predictions = all_preds,
    all_actuals = all_actuals,
    plot_roc = plot_roc,
    plot_prc = plot_prc,
    call = match.call()
  ))
}



evaluate.model <- function(predictions, actual, model.name, threshold = 0.5) {
  
  # Convert probability to binary prediction
  b.pred <- factor(ifelse(predictions > threshold, "1", "0"),
                   levels = c("0", "1"))
  
  # Confusion matrix
  cm <- confusionMatrix(data = b.pred, reference = actual, positive = "1")
  
  # Extract metrics
  accuracy <- cm$overall["Accuracy"]
  sensitivity <- cm$byClass["Sensitivity"]  # Recall
  specificity <- cm$byClass["Specificity"]
  precision <- cm$byClass["Pos Pred Value"]
  f1 <- 2 * (precision * sensitivity) / (precision + sensitivity)
  g.mean <- sqrt(sensitivity * specificity)
  
  # AUC calculation
  if(is.numeric(predictions)) {
    pred.obj <- prediction(predictions, as.numeric(as.character(actual)))
    auc <- performance(pred.obj, "auc")@y.values[[1]]
    aucpr <- performance(pred.obj, "aucpr")@y.values[[1]]
  } else {
    auc <- NA
    aucpr <- NA
  }
  
  # Return results as a data frame row
  results <- data.frame(
    Model = model.name,
    Accuracy = accuracy,
    Sensitivity = sensitivity,
    Specificity = specificity,
    Precision = precision,
    F1_Score = f1,
    G_Mean = g.mean,
    AUC_ROC = auc,
    AUC_PRC = aucpr
  )
  
  return(list(metrics = results, predictions = b.pred,
              probabilities = predictions, cm = cm))
}

#___________________________ROC and PR Curve Plotting___________________________

# Function to create a ROC curve for a single model
plot.roc.curve <- function(probabilities, actual, model.name, add = FALSE, color = "blue") {
  
  # Create ROC object
  pred <- prediction(predictions = probabilities, labels = actual)
  roc.obj <- performance(pred, measure = "tpr", x.measure = "fpr")
  auc <- performance(pred, measure = "auc")@y.values[[1]]
  
  # Plot the ROC curve
  if(!add) {
    plot(roc.obj, 
         col = color, 
         lwd = 2,
         print.auc = TRUE,
         legacy.axes = TRUE,
         xlab = "False Positive Rate", 
         ylab = "True Positive Rate")
  } else {
    plot(roc.obj, 
         col = color, 
         lwd = 2, 
         add = TRUE,
         print.auc = TRUE,
         print.auc.y = 0.45 - (0.05 * which(model.name == names(probabilities.list))))
  }
  
  # Add model name and AUC to legend
  return(list(name = model.name, auc = round(auc, 3)))
}

# Function to create PR curve for a single model
plot.pr.curve <- function(probabilities, actual, model.name, add = FALSE, color = "blue") {
  
  # Convert actual to numeric
  actual.numeric <- as.numeric(as.character(actual))
  
  # Create ROC object
  pred <- prediction(predictions = probabilities, labels = actual)
  prc.obj <- performance(pred, measure = "prec", x.measure = "rec")
  aucpr <- performance(pred, measure = "aucpr")@y.values[[1]]
  
  
  # Plot the PR curve
  if(!add) {
    plot(prc.obj,
         col = color, 
         lwd = 2,
         type = "l", 
         xlab = "Recall",
         ylab = "Precision")
    
    # Add baseline for PR curve (class distribution)
    abline(h = sum(actual.numeric == 1) / length(actual.numeric), lty = 2, col = "gray")
  } else {
    plot(prc.obj, 
         col = color,
         lwd = 2,
         add = TRUE)
  }
  
  # Return model name and AUC-PR for legend
  return(list(name = model.name, auc = round(aucpr, 2)))
}


# =============================================================================
# MAIN PIPELINE
# =============================================================================
# import required data set (Short)
catchment.data <- read.csv("lowland_catchment_data_v2.csv")

# # import required data set (Long)
# catchment.data <- read.csv("upland_catchment_data_v3.csv")

dim(catchment.data)
str(catchment.data)
summary(catchment.data)


#___________________________Data Preparation____________________________________

# 2. Convert data types
df.input <- catchment.data %>%
  mutate(actual = factor(actual, levels = c("No_Drought", "Drought")))

# 3. Explore data
dim(df.input)
str(df.input)


levels(df.input$actual)
summary(df.input)
prop.table(table(df.input$actual))

#______________________________Training/Testing_________________________________

set.seed(123)

# 4. create partition index
train.index <- createDataPartition(df.input$actual, times = 1, p=0.7, list = FALSE)

# 5. create training, testing set
train.set <- df.input[train.index,] 
test.set <- df.input[-train.index,]

# explore data
str(train.set)
str(test.set)

levels(train.set$actual)
levels(test.set$actual)

# Display class distribution
table(train.set$actual)
prop.table(table(train.set$actual))

#______________________________Pre-processing___________________________________

# set.seed
set.seed(123)

# Original dataset
x.train <- train.set[,!colnames(train.set) %in% c("actual")]
y.train <- train.set$actual

x.test <- test.set[,!colnames(test.set) %in% c("actual")]
y.test <- test.set$actual

# binary version for some evaluation metrics
y.test.binary <- factor(ifelse(test.set$actual == "Drought", "1", "0"),
                        levels = c("0", "1"))

#_____________________________Training Control__________________________________


cvcontrol <- trainControl(
  method = "cv",
  number = 10, 
  summaryFunction = twoClassSummary,
  classProbs = TRUE,
  savePredictions = TRUE,
  sampling = "down")

#______________________________baseline model___________________________________

# Create a list to store all results
baseline.results <- list()
baseline.predictions <- list()

hybrid.results <- list()
hybrid.predictions <- list()

# 1. GLM (Generalized Linear Model)
set.seed(123)

glm.model <- train(
    x = x.train, 
    y = y.train, 
    method = "glm",
    preProcess = c("center", "scale"),
    trControl = cvcontrol,
    metric = "ROC"
)
summary(glm.model)

baseline.results[["CV-GLM"]] <- glm.model$results
baseline.predictions[["CV-GLM"]] <- glm.model$pred["Drought"]

glm.predict <- predict(glm.model, x.test, type = "prob")[,"Drought"]
glm.result <- evaluate.model(glm.predict, y.test.binary, "GLM")
baseline.results[["GLM"]] <- glm.result$metrics
baseline.predictions[["GLM"]] <- glm.result$probabilities

# 2. Decision Tree (CART)
set.seed(123)
cart.model <- train(
    x = x.train, 
    y = y.train, 
    method = "rpart",
    preProcess = c("center", "scale"),
    trControl = cvcontrol,
    metric = "ROC"
)

baseline.results[["CV-CART"]] <- cart.model$results
baseline.predictions[["CV-CART"]] <- cart.model$pred["Drought"]

cart.predict <- predict(cart.model, x.test, type = "prob")[,"Drought"]
cart.result <- evaluate.model(cart.predict, y.test.binary, "DT")
baseline.results[["CART"]] <- cart.result$metrics
baseline.predictions[["CART"]] <- cart.result$probabilities

# 6. KNN
set.seed(123)
knn.model <- train(
  x = x.train, 
  y = y.train, 
  method = "knn",
  preProcess = c("center", "scale"),
  trControl = cvcontrol,
  metric = "ROC"
)

baseline.results[["CV-KNN"]] <- knn.model$results
baseline.predictions[["CV-KNN"]] <- knn.model$pred["Drought"]

knn.predict <- predict(knn.model, x.test, type = "prob")[,"Drought"]
knn.result <- evaluate.model(knn.predict, y.test.binary, "KNN")
baseline.results[["KNN"]] <- knn.result$metrics
baseline.predictions[["KNN"]] <- knn.result$probabilities

# 5. Naive Bayes
set.seed(123)
nb.model <- train(
  x = x.train, 
  y = y.train, 
  method = "naive_bayes",
  preProcess = c("center", "scale"),
  trControl = cvcontrol,
  metric = "ROC"
)

baseline.results[["CV-NB"]] <- nb.model$results
baseline.predictions[["CV-NB"]] <- nb.model$pred["Drought"]

nb.predict <- predict(nb.model, x.test, type = "prob")[,"Drought"]
nb.result <- evaluate.model(nb.predict, y.test.binary, "nb")
baseline.results[["NB"]] <- nb.result$metrics
baseline.predictions[["NB"]] <- nb.result$probabilities

# 6. SVM
set.seed(123)
svm.model <- train(
  x = x.train, 
  y = y.train, 
  method = "svmLinear2",
  preProcess = c("center", "scale"),
  trControl = cvcontrol,
  metric = "ROC"
)

baseline.results[["CV-SVM"]] <- svm.model$results
baseline.predictions[["CV-SVM"]] <- svm.model$pred["Drought"]

svm.predict <- predict(svm.model, x.test, type = "prob")[,"Drought"]
svm.result <- evaluate.model(svm.predict, y.test.binary, "SVM")
baseline.results[["SVM"]] <- svm.result$metrics
baseline.predictions[["SVM"]] <- svm.result$probabilities

#________________________________Hybrid Models__________________________________

# 4. Random Forest
set.seed(123)
rf.model <- train(
    x = x.train, 
    y = y.train, 
    method = "rf",
    ntree = 300,
    preProcess = c("center", "scale"),
    trControl = cvcontrol,
    metric = "ROC")

hybrid.results[["CV-RF"]] <- rf.model$results
hybrid.predictions[["CV-RF"]] <- rf.model$pred["Drought"]

rf.predict <- predict(rf.model, x.test, type = "prob")[,"Drought"]
rf.result <- evaluate.model(rf.predict, y.test.binary, "RF")
hybrid.results[["RF"]] <- rf.result$metrics
hybrid.predictions[["RF"]] <- rf.result$probabilities

set.seed(123)
xgb.model <- train(
  x = x.train, 
  y = y.train, 
  method = "xgbLinear",
  preProcess = c("center", "scale"),
  trControl = cvcontrol,
  metric = "ROC"
)

hybrid.results[["CV-XGB"]] <- xgb.model$results
hybrid.predictions[["CV-XGB"]] <- xgb.model$pred["Drought"]

xgb.predict <- predict(xgb.model, x.test, type = "prob")[,"Drought"]
xgb.result <- evaluate.model(xgb.predict, y.test.binary, "XGB")
hybrid.results[["XGB"]] <- xgb.result$metrics
hybrid.predictions[["XGB"]] <- xgb.result$probabilities


# adaBoost
train.data <- list(x = x.train, y = y.train)

# SMOTEBoost
smoterf.model <- smoteboost("rf", train.data, over = 1300, ntree = 300, k_folds = 10, do_plot = FALSE)
smoterf.predict <- predict(smoterf.model$final_model, newdata = x.test, type = "prob")
smoterf.result <- evaluate.model(smoterf.predict, y.test.binary, "SMOTEBoost")

hybrid.results[["CV-SMOTEBoost"]] <- smoterf.model$cv_metrics
hybrid.predictions[["CV-SMOTEBoost"]] <- smoterf.model$all_predictions


hybrid.results[["SMOTEBoost"]] <- smoterf.result$metrics
hybrid.predictions[["SMOTEBoost"]] <- smoterf.result$probabilities


# RUSBoost
rusrf.model <- rusboost("rf", train.data,ir=1, ntree = 300, k_folds = 10, do_plot = FALSE)
rusrf.predict <- predict(rusrf.model$final_model, newdata = x.test, type = "prob")
rusrf.result <- evaluate.model(rusrf.predict, y.test.binary, "RUSBoost")

hybrid.results[["CV-RUSBoost"]] <- rusrf.model$cv_metrics
hybrid.predictions[["CV-RUSBoost"]] <- rusrf.model$all_predictions

hybrid.results[["RUSBoost"]] <- rusrf.result$metrics
hybrid.predictions[["RUSBoost"]] <- rusrf.result$probabilities


#____________________Models Comparisons (ROC & PR curves)_______________________


# Collect probability predictions from baseline models
# here you can change prediction list (e.g. booster.predictions)

probabilities.list <- list()

for(model.name in c("GLM", "CART", "KNN", "NB", "SVM")) {
  probabilities.list[[model.name]] <- baseline.predictions[[model.name]]
}

for(model.name in c("RF", "XGB", "RUSBoost")) {
  probabilities.list[[model.name]] <- hybrid.predictions[[model.name]]
}

names(probabilities.list)[1:2] <- c("LR", "DT")


#__________________________________ROC curve____________________________________

# Set up colors for plotting
num.models <- length(probabilities.list)
colors <- rainbow(num.models)
roc.results <- list()

# Add reference line for random classifier
plot(c(0, 1), c(0, 1), type = "l", lty = 2, col = "gray", 
     xlab = "False Positive Rate", ylab = "True Positive Rate")

# Plot each model's ROC curve
for(i in 1:length(probabilities.list)) {
  model.name <- names(probabilities.list)[i]
  roc.results[[i]] <- plot.roc.curve(
    probabilities.list[[model.name]], 
    y.test.binary, 
    model.name, 
    add = TRUE, 
    color = colors[i]
  )
}

# Sort ROC results by AUC in descending order
auc.values <- sapply(roc.results, function(x) x$auc)
sorted.indices <- order(auc.values, decreasing = TRUE)
roc.results.sorted <- roc.results[sorted.indices]
roc.colors.sorted <- colors[sorted.indices]

# Add the legend outside the plot (to the right)
legend("bottomright", 
       legend = sapply(roc.results.sorted, 
                       function(x) paste0(x$name)),
       col = roc.colors.sorted, 
       lwd = 2, 
       cex = 0.9)


#_____________________________________PR curve__________________________________

prc.results <- list()

# Set up empty plot
plot(0, 0, type = "n", xlim = c(0, 1), ylim = c(0, 1),
     xlab = "Recall", ylab = "Precision")

# Add baseline for PR curve (class distribution)
abline(h = sum(as.numeric(as.character(y.test.binary)) == 1) / length(y.test.binary), 
       lty = 2, col = "gray")


# Plot each model's PR curve
for(i in 1:length(probabilities.list)) {
  model.name <- names(probabilities.list)[i]
  prc.results[[i]] <- plot.pr.curve(
    probabilities.list[[model.name]], 
    y.test.binary, 
    model.name, 
    add = TRUE, 
    color = colors[i]
  )
}

# Sort ROC results by AUC in descending order
aucpr.values <- sapply(prc.results, function(x) x$auc)
sorted.indices <- order(aucpr.values, decreasing = TRUE)
prc.results.sorted <- prc.results[sorted.indices]
prc.colors.sorted <- colors[sorted.indices]

# Add legend outside the plot
legend("topright", 
       legend = sapply(prc.results.sorted, function(x) paste(x$name)),
       col = prc.colors.sorted, 
       lwd = 2,
       cex = 0.9)
 
#______________________________Model comparisons________________________________

model.results$Method <- factor(model.results$Method, 
                               levels = unique(model.results$Method))

# Reshape data for ggplot
model.long <- pivot_longer(model.results, cols = -Method,
                           names_to = "Metric", values_to = "Score")

# Plot
ggplot(model.long, aes(x = Method, y = Score, fill = Metric)) +
  geom_bar(stat = "identity", position = position_dodge()) +
  theme_minimal() +
  labs(y = "Score", x = "Model") +
  theme()

#________________________ROC & PR curve for the best model______________________

# this code works will with caret models, just select the model in cv.preds
# use plot size 650 x 600

cv.preds <- rf.model$pred
folds <- unique(cv.preds$Resample)

# Convert probability to binary prediction
cv.preds$obs <- factor(ifelse(cv.preds$obs =="Drought", "1", "0"),
                 levels = c("0", "1"))

# Define colors for folds
colors <- rainbow(length(folds))
auc.values <- numeric(length(folds))
aucpr.values <- numeric(length(folds))

# Initialize an empty plot (first fold)
first.fold <- folds[1]
first.fold.data <- cv.preds[cv.preds$Resample == first.fold,] 
first.prediction <- prediction(first.fold.data$Drought, first.fold.data$obs)

first.roc <- performance(first.prediction, measure = "tpr", x.measure = "fpr")

# Plot first ROC curve
plot(first.roc, col = colors[1], lwd = 2, xlab = "False Positive Rate", 
     ylab = "True Positive Rate")

# Loop through remaining folds and add ROC curves
for (i in seq_along(folds)) {
  fold <- folds[i]
  fold.data <- cv.preds[cv.preds$Resample == fold, ] 
  
  # Generate ROC data
  fold.prediction <- prediction(fold.data$Drought, fold.data$obs)
  fold.roc <- performance(fold.prediction, measure = "tpr", x.measure = "fpr")
  
  # Compute AUC
  fold.auc <- performance(fold.prediction, measure = "auc")@y.values[[1]]
  auc.values[i] <- fold.auc  # Store AUC for the fold
  
  # Add ROC curve to the plot
  plot(fold.roc, col = colors[i], lwd = 2, add = TRUE)
}

# Add diagonal reference line
abline(a = 0, b = 1, lty = 2, col = "black")

# Compute mean AUC
mean.auc <- mean(auc.values)

legend("bottomright", 
       legend = c(paste("Fold", 1:length(folds), "(AUC =", round(auc.values, 2), ")"), 
                  paste("Mean AUC:", round(mean.auc, 2))), 
       col = c(colors, "black"), lwd = 2, cex = 0.6)

#_______________________________ AUCPR Results__________________________________


first.prc <- performance(first.prediction, measure = "prec", x.measure = "rec")

fold.aucpr <- performance(first.prediction, measure = "aucpr")@y.values[[1]]

# Plot first ROC curve
plot(first.prc, col = colors[1], lwd = 2, xlab = "Recall", 
     ylab = "Precision")

# Loop through remaining folds and add ROC curves
for (i in seq_along(folds)) {
  
  fold <- folds[i]
  fold.data <- cv.preds[cv.preds$Resample == fold, ]
  
  # Generate ROC data
  fold.prediction <- prediction(fold.data$Drought, fold.data$obs)
  fold.prc <- performance(fold.prediction, measure = "prec", x.measure = "rec")
  
  # Compute AUC
  fold.aucpr <- performance(fold.prediction, measure = "aucpr")@y.values[[1]]
  aucpr.values[i] <- fold.aucpr  # Store AUC for the fold
  
  # Add ROC curve to the plot
  plot(fold.prc, col = colors[i], lwd = 2, add = TRUE)
}

# Add baseline for PR curve (class distribution)
abline(h = sum(as.numeric(as.character(y.test.binary)) == 1) / length(y.test.binary), 
       lty = 2, col = "gray")

# Compute mean AUC
mean.aucpr <- mean(aucpr.values)

legend("topright", 
       legend = c(paste("Fold", 1:length(folds), 
                        "(AUCPR =", round(aucpr.values, 2), ")"),
                  paste("Mean AUCPR:", round(mean.aucpr, 2))), 
       col = c(colors, "black"), lwd = 2, cex = 0.6)

#--------------------------------Final Evaluation results-----------------------

df <- data.frame(rusrf.model$cv_results) %>% 
    select(-c(auc, aucpr))

names(df)[1] <- "Accuracy"

df_long <- pivot_longer(df, cols = everything(), names_to = "Metric", values_to = "Value")

# Define your desired order
desired_order <- c("Accuracy", "Sensitivity", "Specificity", "Precision", "F1")

# Update df_long to use that order
df_long$Metric <- factor(df_long$Metric, levels = desired_order)

# Now plot
ggplot(df_long, aes(x = Metric, y = Value, fill = Metric)) +
    geom_boxplot() +
    labs(title = "Cross-Validation Metrics Comparison",
         y = "Score",
         x = "Metric") +
    theme_minimal() +
    theme(legend.position = "none")
