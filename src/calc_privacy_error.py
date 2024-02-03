import sys
import polars as pl

def main():

    base_analytics = pl.read_csv(sys.argv[1])

    # compute a weight column that is the proportion of the total count
    base_analytics = base_analytics.with_columns(
        (pl.col('count') / pl.sum("count")).alias('weight')
    )
    
    infns = sys.argv[2:-2]

    dtypes = {
        'epsilon': pl.Utf8,
        'sensitivity': pl.Utf8,
        'm': pl.Utf8,
        'k': pl.Utf8
    }

    # concat all files
    df = pl.read_csv(infns[0],
                    dtypes=dtypes)
    for infn in infns[1:]:
        df = pl.concat([df, pl.read_csv(infn, dtypes=dtypes)])

    df = df.rename({'count': 'count_private'})
    df = df.join(base_analytics, on=['geoid_o', 'geoid_d'])

    # This could be made into a single function for annotations in fig 3
    df = df.with_columns(
        ((pl.col('count_private') - pl.col('count')) ** 2).alias('squared_error'),
        ((pl.col('count_private') - pl.col('count')) ** 2 * pl.col('weight'))
        .alias('weighted_squared_error'),
        ((pl.col('count_private') - pl.col('count')).abs() / (pl.col('count')) * 100)
        .alias('absolute_percentage_error'),
        ((pl.col('count_private') - pl.col('count')).abs() / (pl.col('count') + 1e-8) * 100 * pl.col('weight'))
        .alias('weighted_absolute_percentage_error')
        )
    
    metrics_df = (
        df.groupby(['construction', 'k', 'm', 'epsilon', 'sensitivity'])
        .agg([
            pl.mean('squared_error').alias('mean_squared_error'),
            pl.sum('weighted_squared_error').alias('sum_weighted_squared_error'),
            pl.mean('absolute_percentage_error').alias('mean_absolute_percentage_error'),
            pl.sum('weighted_absolute_percentage_error').alias('sum_weighted_absolute_percentage_error'),
            pl.sum('weight').alias('sum_weight')
        ])
        .with_columns([
            pl.col('mean_squared_error').sqrt().alias('rmse'),
            (pl.col('sum_weighted_squared_error').sqrt() / pl.col('sum_weight')).alias('weighted_rmse'),
            pl.col('mean_absolute_percentage_error').alias('mape'),
            (pl.col('sum_weighted_absolute_percentage_error') / pl.col('sum_weight')).alias('weighted_mape')
        ])
        .drop(['mean_squared_error', 'mean_absolute_percentage_error', 'sum_weighted_squared_error', 'sum_weighted_absolute_percentage_error', 'sum_weight'])
    )

    df.write_csv(sys.argv[-2])
    metrics_df.write_csv(sys.argv[-1])

if __name__ == '__main__':
    main()