test_that("rzip works", {

  expect_true(all(rzip(10, 0, 1) == 0))

  diff_mean <- vapply(1:5,
         function(x) {
           abs(mean(rzip(1e3, 1, x)) - x)
         }, numeric(1))
  expect_true(all(diff_mean < 0.1))

})
