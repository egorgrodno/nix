return {
  parse('_ti', '<${1:div}>${2}</${1}>'),

  parse('_tb', [[
<${1:div}>
  ${2}
</${1}>
  ]]),
  parse('_im', 'import {${2}} from \'${1}\''),

  parse('_imfp', [[
import { array as A, either as E, option as O, taskEither as TE } from 'fp-ts'
import { flow, identity, pipe } from 'fp-ts/function'
  ]]),

  parse('_rc', [[
import { FC${1} } from 'react'
import { Box, Grid, Typography, styled } from '@mui/material'

export const Component: FC<Props> = props => {
  return (
    null
  )
}
  ]]),
  parse('_cl', [[
console.log(${1})
  ]]),
}
