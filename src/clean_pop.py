import sys
import polars as pl

def main():

    import sys
    print(f"DEBUG: Python path: {sys.path}")

    pop = pl.read_csv(
        sys.argv[1],
        columns=['STATE', 'COUNTY', 'STNAME', 'CTYNAME', 'POPESTIMATE2019'],
        dtypes={'STATE': pl.Utf8, 'COUNTY': pl.Utf8},
        encoding='utf8-lossy'
    )

    pop = pop.with_columns(
        (pop['STATE'] + pop['COUNTY']).alias('GEOID')
    )
    
    pop = pop.filter(pl.col('COUNTY') != '000')

    pop = pop.drop(['STATE', 'COUNTY'])

    pop.write_csv(sys.argv[2])


if __name__ == '__main__':
    main()