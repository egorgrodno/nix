return {
  parse('ti', '<${1:div}>${2}</${1}>'),

  parse('tb', [[
<${1:div}>
  ${2}
</${1}>
  ]]),
  parse('im', 'import {${2}} from \'${1}\''),

  parse('imfp', [[
import { array as A, either as E, option as O, taskEither as TE } from 'fp-ts'
import { flow, identity, pipe } from 'fp-ts/function'
  ]]),

  parse('rc', [[
import { FC${1} } from 'react'
import { Box, Grid, Typography, styled } from '@mui/material'

export const Component: FC<Props> = props => {
  return (
    null
  )
}
  ]]),
}
