source("R/functions.R")

set.seed(5)

N_train <- 100 # Number of observations for training
N_test <- 1000 # Number of observations for testing
D <- 30 # Number of dimensions/features

fakedata <- generate_fakedata(N = N_train + N_test, D = D, D_bin = 2)
fakedata_split <- prepare_train_test(fakedata$Data, N_train = N_train)

write.csv(fakedata_split$Train, file = "data/train.csv", row.names = FALSE)
write.csv(fakedata_split$Test, file = "data/test.csv", row.names = FALSE)
write.csv(fakedata$Beta, file = "data/beta.csv", row.names = FALSE)
